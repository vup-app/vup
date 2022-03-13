package net.redsolver.vup

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.annotation.Nullable
import com.mr.flutter.plugin.filepicker.FileUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity: FlutterActivity() {
  private val CHANNEL = "net.redsolver.vup/app"

  private val PICK_DIRECTORY = 44;

  private var pendingResult: MethodChannel.Result? = null


  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
      // Note: this method is invoked on the main thread.
      call, result ->
      if (call.method == "requestManageAllFilesPermission") {
        result.success(true)
      } else if (call.method == "pickDirectory") {
        this.pendingResult = result;
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        intent.addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        startActivityForResult(intent, PICK_DIRECTORY);
        // result.success(true)

      } else {
        result.notImplemented()
      }
    }
  }
  override fun onActivityResult(requestCode: Int, resultCode: Int, @Nullable data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    if (requestCode == PICK_DIRECTORY && resultCode == Activity.RESULT_OK) {

      var uri: Uri? = null
      if (data != null) {
        uri = data.data
        contentResolver.takePersistableUriPermission(uri!!, Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        uri = DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri));
        // contentResolver.takePersistableUriPermission(uri, flags);

        val dirPath = FileUtils.getFullPathFromTreeUri(uri, activity);
        if(dirPath != null) {
          this.pendingResult?.success(dirPath);
          this.pendingResult = null;
        } else {
          this.pendingResult?.error("unknown_path","Failed to retrieve directory path.",null);
          this.pendingResult = null;

        }
        return;
      }
    }
  }

  private fun requestManageAllFilesPermission() {
    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION);
    this.activity.startActivity(intent);
  }

}
