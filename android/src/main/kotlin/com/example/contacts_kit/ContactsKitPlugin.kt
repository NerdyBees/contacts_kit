package com.example.contacts_kit

import android.Manifest
import android.content.ContentResolver
import android.content.pm.PackageManager
import android.database.Cursor
import android.provider.ContactsContract
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import android.app.Activity
import kotlinx.coroutines.*

class ContactsKitPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null
    private val PERMISSION_REQUEST_CODE = 1001
    private val TAG = "ContactsKit"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "contacts_kit")
        channel.setMethodCallHandler(this)
    }

override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "requestPermission" -> requestPermission(result)
            "hasPermission" -> hasPermission(result)
            "getAllContacts" -> {

                val withPhones = call.argument<Boolean>("withPhones") ?: true
                val withEmails = call.argument<Boolean>("withEmails") ?: true
                val withStructuredNames = call.argument<Boolean>("withStructuredNames") ?: true

                getAllContacts(result, withPhones, withEmails, withStructuredNames)
            }
            "getContactsCount" -> getContactsCount(result)
            else -> result.notImplemented()
        }
    }

    private fun requestPermission(result: Result) {
        val activity = activity ?: run {
            result.error("NO_ACTIVITY", "Activity is null", null)
            return
        }

        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_CONTACTS)
            == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
        } else {
            pendingResult = result
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.READ_CONTACTS),
                PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun hasPermission(result: Result) {
        val activity = activity ?: run {
            result.error("NO_ACTIVITY", "Activity is null", null)
            return
        }

        val granted = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.READ_CONTACTS
        ) == PackageManager.PERMISSION_GRANTED
        result.success(granted)
    }

private fun getAllContacts(
        result: Result,
        withPhones: Boolean,
        withEmails: Boolean,
        withStructuredNames: Boolean
    ) {
        val startTime = System.currentTimeMillis()
        Log.d(TAG, "Starting to fetch contacts...")

        val activity = activity ?: run {
            result.error("NO_ACTIVITY", "Activity is null", null)
            return
        }

        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_CONTACTS)
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Contacts permission not granted", null)
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                // 💡 MODIFIED: Pass flags to fetchContacts
                val contacts = fetchContacts(
                    activity.contentResolver,
                    withPhones,
                    withEmails,
                    withStructuredNames
                )
                val totalTime = System.currentTimeMillis() - startTime

                Log.d(TAG, "✅ Successfully fetched ${contacts.size} contacts")
                Log.d(TAG, "⏱️  Total time: ${totalTime}ms (${totalTime / 1000.0}s)")

                withContext(Dispatchers.Main) {
                    result.success(contacts)
                }
            } catch (e: Exception) {
                val totalTime = System.currentTimeMillis() - startTime
                Log.e(TAG, "❌ Error fetching contacts after ${totalTime}ms: ${e.message}")

                withContext(Dispatchers.Main) {
                    result.error("FETCH_ERROR", e.message, null)
                }
            }
        }
    }


    private fun fetchContacts(
        contentResolver: ContentResolver,
        withPhones: Boolean,
        withEmails: Boolean,
        withStructuredNames: Boolean
    ): List<Map<String, Any>> {
        val contactsMap = mutableMapOf<String, MutableMap<String, Any>>()

        val step1Start = System.currentTimeMillis()


        val cursor: Cursor? = contentResolver.query(
             ContactsContract.Contacts.CONTENT_URI,
             null, null, null,
             ContactsContract.Contacts.DISPLAY_NAME + " ASC"
         )

        cursor?.use {
             val idIndex = it.getColumnIndex(ContactsContract.Contacts._ID)
             val nameIndex = it.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME)

             while (it.moveToNext()) {
                 val id = it.getString(idIndex)
                 val name = it.getString(nameIndex) ?: ""

                 contactsMap[id] = mutableMapOf(
                     "id" to id,
                     "displayName" to name,
                     "givenName" to "",
                     "familyName" to "",
                     "phones" to mutableListOf<String>(),
                     "emails" to mutableListOf<String>()
                 )
             }
         }

        val step1Time = System.currentTimeMillis() - step1Start

        var step2Time = 0L
        if (withPhones) {
            val step2Start = System.currentTimeMillis()

            val phoneCursor: Cursor? = contentResolver.query(
                 ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                 null, null, null, null
             )

            var phoneCount = 0
            phoneCursor?.use {
                 val contactIdIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
                 val phoneIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)

                 while (it.moveToNext()) {
                     val contactId = it.getString(contactIdIndex)
                     val phone = it.getString(phoneIndex) ?: ""

                     contactsMap[contactId]?.let { contact ->
                         (contact["phones"] as MutableList<String>).add(phone)
                         phoneCount++
                     }
                 }
             }
             step2Time = System.currentTimeMillis() - step2Start
             Log.d(TAG, "   ✓ Found $phoneCount phone numbers in ${step2Time}ms")
        } else {
             Log.d(TAG, "📞 Step 2: Skipping phone numbers.")
        }

        var step3Time = 0L
        if (withEmails) {
            val step3Start = System.currentTimeMillis()
            Log.d(TAG, "📧 Step 3: Fetching emails...")

            val emailCursor: Cursor? = contentResolver.query(
                 ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                 null, null, null, null
             )

            var emailCount = 0
            emailCursor?.use {
                 val contactIdIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Email.CONTACT_ID)
                 val emailIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Email.ADDRESS)

                 while (it.moveToNext()) {
                     val contactId = it.getString(contactIdIndex)
                     val email = it.getString(emailIndex) ?: ""

                     contactsMap[contactId]?.let { contact ->
                         (contact["emails"] as MutableList<String>).add(email)
                         emailCount++
                     }
                 }
             }
             step3Time = System.currentTimeMillis() - step3Start
             Log.d(TAG, "   ✓ Found $emailCount emails in ${step3Time}ms")
        } else {
             Log.d(TAG, "📧 Step 3: Skipping emails.")
        }

        var step4Time = 0L
        if (withStructuredNames) {
            val step4Start = System.currentTimeMillis()
            Log.d(TAG, "👤 Step 4: Fetching structured names...")

            // 💡 ONLY runs if withStructuredNames is true
            val nameCursor: Cursor? = contentResolver.query(
                 ContactsContract.Data.CONTENT_URI,
                 null,
                 ContactsContract.Data.MIMETYPE + " = ?",
                 arrayOf(ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE),
                 null
             )

            var nameCount = 0
            nameCursor?.use {
                 val contactIdIndex = it.getColumnIndex(ContactsContract.Data.CONTACT_ID)
                 val givenNameIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME)
                 val familyNameIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME)

                 while (it.moveToNext()) {
                     val contactId = it.getString(contactIdIndex)
                     val givenName = it.getString(givenNameIndex) ?: ""
                     val familyName = it.getString(familyNameIndex) ?: ""

                     contactsMap[contactId]?.let { contact ->
                         contact["givenName"] = givenName
                         contact["familyName"] = familyName
                         nameCount++
                     }
                 }
             }
             step4Time = System.currentTimeMillis() - step4Start
             Log.d(TAG, "   ✓ Found $nameCount structured names in ${step4Time}ms")
        } else {
             Log.d(TAG, "👤 Step 4: Skipping structured names.")
        }


        Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.d(TAG, "Performance Summary:")
        Log.d(TAG, "  Step 1 (Basic Info):     ${step1Time}ms")
        Log.d(TAG, "  Step 2 (Phone Numbers):  ${if (withPhones) "${step2Time}ms" else "SKIPPED"}")
        Log.d(TAG, "  Step 3 (Emails):         ${if (withEmails) "${step3Time}ms" else "SKIPPED"}")
        Log.d(TAG, "  Step 4 (Structured Names): ${if (withStructuredNames) "${step4Time}ms" else "SKIPPED"}")
        val totalTime = step1Time + step2Time + step3Time + step4Time
        Log.d(TAG, "  Total Fetch Time: ${totalTime}ms")
        Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


        return contactsMap.values.toList()
    }

    private fun getContactsCount(result: Result) {
        val activity = activity ?: run {
            result.error("NO_ACTIVITY", "Activity is null", null)
            return
        }

        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_CONTACTS)
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Contacts permission not granted", null)
            return
        }

        val cursor = activity.contentResolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            null, null, null, null
        )
        val count = cursor?.count ?: 0
        cursor?.close()
        result.success(count)
    }

    private fun fetchContacts(contentResolver: ContentResolver): List<Map<String, Any>> {
        val contactsMap = mutableMapOf<String, MutableMap<String, Any>>()

        // Step 1: Fetch basic contact info
        val step1Start = System.currentTimeMillis()
        Log.d(TAG, "📋 Step 1: Fetching basic contact info...")

        val cursor: Cursor? = contentResolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            null, null, null,
            ContactsContract.Contacts.DISPLAY_NAME + " ASC"
        )

        cursor?.use {
            val idIndex = it.getColumnIndex(ContactsContract.Contacts._ID)
            val nameIndex = it.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME)

            while (it.moveToNext()) {
                val id = it.getString(idIndex)
                val name = it.getString(nameIndex) ?: ""

                contactsMap[id] = mutableMapOf(
                    "id" to id,
                    "displayName" to name,
                    "givenName" to "",
                    "familyName" to "",
                    "phones" to mutableListOf<String>(),
                    "emails" to mutableListOf<String>()
                )
            }
        }

        val step1Time = System.currentTimeMillis() - step1Start
        Log.d(TAG, "   ✓ Found ${contactsMap.size} contacts in ${step1Time}ms")

        // Step 2: Fetch phone numbers
        val step2Start = System.currentTimeMillis()
        Log.d(TAG, "📞 Step 2: Fetching phone numbers...")

        val phoneCursor: Cursor? = contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            null, null, null, null
        )

        var phoneCount = 0
        phoneCursor?.use {
            val contactIdIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
            val phoneIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)

            while (it.moveToNext()) {
                val contactId = it.getString(contactIdIndex)
                val phone = it.getString(phoneIndex) ?: ""

                contactsMap[contactId]?.let { contact ->
                    (contact["phones"] as MutableList<String>).add(phone)
                    phoneCount++
                }
            }
        }

        val step2Time = System.currentTimeMillis() - step2Start
        Log.d(TAG, "   ✓ Found $phoneCount phone numbers in ${step2Time}ms")

        // Step 3: Fetch emails
        val step3Start = System.currentTimeMillis()
        Log.d(TAG, "📧 Step 3: Fetching emails...")

        val emailCursor: Cursor? = contentResolver.query(
            ContactsContract.CommonDataKinds.Email.CONTENT_URI,
            null, null, null, null
        )

        var emailCount = 0
        emailCursor?.use {
            val contactIdIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Email.CONTACT_ID)
            val emailIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Email.ADDRESS)

            while (it.moveToNext()) {
                val contactId = it.getString(contactIdIndex)
                val email = it.getString(emailIndex) ?: ""

                contactsMap[contactId]?.let { contact ->
                    (contact["emails"] as MutableList<String>).add(email)
                    emailCount++
                }
            }
        }

        val step3Time = System.currentTimeMillis() - step3Start
        Log.d(TAG, "   ✓ Found $emailCount emails in ${step3Time}ms")

        // Step 4: Fetch structured names
        val step4Start = System.currentTimeMillis()
        Log.d(TAG, "👤 Step 4: Fetching structured names...")

        val nameCursor: Cursor? = contentResolver.query(
            ContactsContract.Data.CONTENT_URI,
            null,
            ContactsContract.Data.MIMETYPE + " = ?",
            arrayOf(ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE),
            null
        )

        var nameCount = 0
        nameCursor?.use {
            val contactIdIndex = it.getColumnIndex(ContactsContract.Data.CONTACT_ID)
            val givenNameIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME)
            val familyNameIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME)

            while (it.moveToNext()) {
                val contactId = it.getString(contactIdIndex)
                val givenName = it.getString(givenNameIndex) ?: ""
                val familyName = it.getString(familyNameIndex) ?: ""

                contactsMap[contactId]?.let { contact ->
                    contact["givenName"] = givenName
                    contact["familyName"] = familyName
                    nameCount++
                }
            }
        }

        val step4Time = System.currentTimeMillis() - step4Start
        Log.d(TAG, "   ✓ Found $nameCount structured names in ${step4Time}ms")

        // Summary
        Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.d(TAG, "Performance Summary:")
        Log.d(TAG, "  Step 1 (Basic Info):     ${step1Time}ms")
        Log.d(TAG, "  Step 2 (Phone Numbers):  ${step2Time}ms")
        Log.d(TAG, "  Step 3 (Emails):         ${step3Time}ms")
        Log.d(TAG, "  Step 4 (Structured Names): ${step4Time}ms")
        Log.d(TAG, "  Total Fetch Time: ${step1Time + step2Time + step3Time + step4Time}ms")
        Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        return contactsMap.values.toList()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                         grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(granted)
            pendingResult = null
            return true
        }
        return false
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}