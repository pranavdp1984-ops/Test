<!---
    Lucee File Upload Test Page
    - Accepts a file upload (any size)
    - Shows file details: name, size, type, upload duration
    - Reports whether the upload succeeded or failed
    - Cleans up the temp file after inspection
--->
<cfset pageStart = getTickCount()>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Lucee File Upload Test</title>
    <style>
        body  { font-family: monospace; max-width: 680px; margin: 40px auto; padding: 0 16px; }
        h1    { font-size: 1.3rem; }
        h2    { font-size: 1.1rem; margin-top: 24px; }
        label { display: block; margin: 16px 0 4px; font-weight: bold; }
        input[type=file]   { font-size: 1rem; }
        input[type=submit] { margin-top: 14px; padding: 8px 20px; font-size: 1rem; cursor: pointer; }
        .result  { margin-top: 24px; background: #f4f4f4; padding: 16px; border-radius: 4px; }
        table    { border-collapse: collapse; width: 100%; }
        td       { padding: 5px 8px; vertical-align: top; }
        td:first-child { font-weight: bold; white-space: nowrap; width: 200px; }
        .ok      { color: green; font-weight: bold; }
        .err     { color: red;   font-weight: bold; }
        .warn    { color: orange; }
        .bar-wrap{ background:#ddd; border-radius:3px; height:14px; width:100%; margin-top:4px; }
        .bar     { background:#4a90d9; height:14px; border-radius:3px; }
        pre      { background:#fff; border:1px solid #ddd; padding:10px; overflow:auto; font-size:.85rem; }
    </style>
</head>
<body>

<h1>Lucee File Upload Test</h1>
<p>Choose any file (including large ones) to test whether Lucee can receive it.
The page shows file details and total upload + processing time.</p>

<cfif CGI.REQUEST_METHOD NEQ "POST">
<!--- ── GET: show the upload form ──────────────────────────────────────── --->

<form method="post" action="#CGI.SCRIPT_NAME#" enctype="multipart/form-data">

    <label for="uploadFile">Select file to upload:</label>
    <input type="file" id="uploadFile" name="uploadFile" required>

    <input type="submit" value="Upload &amp; Test">
</form>

<cfelse>
<!--- ── POST: process the upload ───────────────────────────────────────── --->

<cfset uploadOk     = false>
<cfset errMessage   = "">
<cfset uploadDir    = getTempDirectory()>

<cftry>

    <!--- cffile action=upload saves to a temp folder --->
    <cffile
        action     = "upload"
        filefield  = "form.uploadFile"
        destination= "#uploadDir#"
        nameconflict= "makeunique"
        result     = "uploadResult"
    >

    <cfset uploadOk = true>

    <!--- Gather stats from the upload result struct --->
    <cfset savedPath   = uploadResult.serverDirectory & "/" & uploadResult.serverFile>
    <cfset clientName  = uploadResult.clientFile>
    <cfset serverName  = uploadResult.serverFile>
    <cfset mimeType    = uploadResult.contentType & "/" & uploadResult.contentSubType>
    <cfset fileExt     = uploadResult.serverFileExt>

    <!--- Get actual byte size from disk --->
    <cfset fileInfo    = getFileInfo(savedPath)>
    <cfset byteSize    = fileInfo.size>

    <!--- Human-readable size --->
    <cfif byteSize GTE 1073741824>
        <cfset humanSize = NumberFormat(byteSize / 1073741824, "0.00") & " GB">
    <cfelseif byteSize GTE 1048576>
        <cfset humanSize = NumberFormat(byteSize / 1048576, "0.00") & " MB">
    <cfelseif byteSize GTE 1024>
        <cfset humanSize = NumberFormat(byteSize / 1024, "0.00") & " KB">
    <cfelse>
        <cfset humanSize = byteSize & " bytes">
    </cfif>

    <!--- Total time including network transfer --->
    <cfset totalMs = getTickCount() - pageStart>

    <!--- Throughput (bytes per second) --->
    <cfif totalMs GT 0>
        <cfset bps       = Int(byteSize / (totalMs / 1000))>
        <cfif bps GTE 1048576>
            <cfset throughput = NumberFormat(bps / 1048576, "0.00") & " MB/s">
        <cfelseif bps GTE 1024>
            <cfset throughput = NumberFormat(bps / 1024, "0.00") & " KB/s">
        <cfelse>
            <cfset throughput = bps & " B/s">
        </cfif>
    <cfelse>
        <cfset throughput = "N/A">
    </cfif>

    <!--- Clean up – delete the temp file after inspection --->
    <cffile action="delete" file="#savedPath#">

    <cfcatch type="any">
        <cfset uploadOk   = false>
        <cfset errMessage = cfcatch.message & " — " & cfcatch.detail>
    </cfcatch>
</cftry>

<!--- ── Results ──────────────────────────────────────────────────────────── --->
<div class="result">
    <h2>Upload Result:
        <cfif uploadOk>
            <span class="ok">SUCCESS &#10003;</span>
        <cfelse>
            <span class="err">FAILED &#10007;</span>
        </cfif>
    </h2>

    <cfif uploadOk>
    <table>
        <tr>
            <td>Original filename</td>
            <td>#HTMLEditFormat(clientName)#</td>
        </tr>
        <tr>
            <td>Saved as (server)</td>
            <td>#HTMLEditFormat(serverName)#</td>
        </tr>
        <tr>
            <td>MIME type</td>
            <td>#HTMLEditFormat(mimeType)#</td>
        </tr>
        <tr>
            <td>Extension</td>
            <td>#HTMLEditFormat(fileExt)#</td>
        </tr>
        <tr>
            <td>File size</td>
            <td>
                #humanSize# (#NumberFormat(byteSize)# bytes)
                <!--- visual bar scaled against 100 MB --->
                <cfset barPct = Min(100, Int(byteSize / 1048576))><!--- 1 px per MB, cap 100 --->
                <cfif barPct GT 0>
                <div class="bar-wrap"><div class="bar" style="width:#barPct#%"></div></div>
                </cfif>
            </td>
        </tr>
        <tr>
            <td>Total time (upload + save)</td>
            <td>#totalMs# ms</td>
        </tr>
        <tr>
            <td>Throughput (est.)</td>
            <td>#throughput#</td>
        </tr>
        <tr>
            <td>Temp file cleaned up?</td>
            <td><span class="ok">Yes</span></td>
        </tr>
    </table>

    <cfelse>
    <!--- Show error details --->
    <p class="err">Error details:</p>
    <pre>#HTMLEditFormat(errMessage)#</pre>

    <p class="warn">Common causes for large-file failures:</p>
    <ul>
        <li>Lucee <code>this.maxRequestSize</code> or <code>this.maxFileSize</code> too low in <code>Application.cfc</code></li>
        <li>Web server (nginx/Apache/IIS) <code>client_max_body_size</code> / <code>LimitRequestBody</code> setting</li>
        <li>Servlet container <code>maxPostSize</code> in <code>web.xml</code> or Tomcat connector config</li>
        <li>PHP-style <code>upload_max_filesize</code> (not applicable to Lucee but check proxy layer)</li>
    </ul>
    </cfif>
</div>

<p><a href="#CGI.SCRIPT_NAME#">&larr; Upload another file</a></p>

</cfif><!--- end POST --->

</body>
</html>
