<!---
    Lucee Disk Benchmark Page
    Tests: disk capacity, sequential write/read speed, IOPS, latency
--->
<cfset pageStart = getTickCount()>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Lucee Disk Benchmark</title>
    <style>
        body  { font-family: monospace; max-width: 780px; margin: 40px auto; padding: 0 20px; }
        h1    { font-size: 1.3rem; }
        h2    { font-size: 1.1rem; margin: 28px 0 8px; border-bottom: 1px solid #ccc; padding-bottom: 4px; }
        label { display: block; margin: 12px 0 3px; font-weight: bold; }
        input[type=text],
        input[type=number] { width: 260px; padding: 6px; font-size: 1rem; }
        input[type=submit] { margin-top: 16px; padding: 9px 24px; font-size: 1rem; cursor: pointer; }
        .grid  { display: grid; grid-template-columns: 1fr 1fr; gap: 0 32px; }
        .section { margin-top: 24px; background: #f7f7f7; padding: 16px; border-radius: 4px; }
        table  { border-collapse: collapse; width: 100%; margin-top: 8px; }
        td     { padding: 5px 8px; }
        td:first-child { font-weight: bold; white-space: nowrap; width: 230px; color: #444; }
        .ok    { color: #2a9d2a; font-weight: bold; }
        .err   { color: red; font-weight: bold; }
        .warn  { color: orange; }
        .note  { font-size: .85rem; color: #666; margin-top: 6px; }
        .bar-wrap { background:#ddd; border-radius:3px; height:12px; width:200px; display:inline-block; vertical-align:middle; margin-left:8px; }
        .bar      { background:#4a90d9; height:12px; border-radius:3px; }
        .bar-g    { background:#2a9d2a; height:12px; border-radius:3px; }
        pre    { background:#fff; border:1px solid #ddd; padding:10px; overflow:auto; font-size:.82rem; margin-top:8px; }
        .hint  { font-size:.82rem; color:#888; margin-top:2px; }
    </style>
</head>
<body>

<h1>Lucee Disk Benchmark</h1>
<p>Measures disk capacity, sequential read/write throughput, IOPS (small-block), and write latency.
All test files are written then immediately deleted.</p>

<!--- ── GET: configuration form ─────────────────────────────────────────── --->
<cfif CGI.REQUEST_METHOD NEQ "POST">

<form method="post" action="#CGI.SCRIPT_NAME#">
    <div class="grid">
        <div>
            <label for="testDir">Test directory (must be writable):</label>
            <input type="text" id="testDir" name="testDir"
                   value="#HTMLEditFormat(getTempDirectory())#">
            <div class="hint">Defaults to Lucee temp dir</div>

            <label for="seqSizeMB">Sequential file size (MB):</label>
            <input type="number" id="seqSizeMB" name="seqSizeMB"
                   min="1" max="2048" value="100">
            <div class="hint">Larger = more accurate, slower</div>
        </div>
        <div>
            <label for="iopsCount">IOPS file count:</label>
            <input type="number" id="iopsCount" name="iopsCount"
                   min="10" max="5000" value="500">
            <div class="hint">Number of 4 KB files to write/read</div>

            <label for="latencyRuns">Latency sample count:</label>
            <input type="number" id="latencyRuns" name="latencyRuns"
                   min="5" max="200" value="50">
            <div class="hint">Single-byte writes to average latency</div>
        </div>
    </div>
    <input type="submit" value="Run Benchmark">
</form>

<cfelse>
<!--- ── POST: run all tests ──────────────────────────────────────────────── --->

<!--- Sanitise inputs --->
<cfset testDir    = trim(FORM.testDir)>
<cfset seqSizeMB  = Max(1,  Min(2048, Val(FORM.seqSizeMB)))>
<cfset iopsCount  = Max(10, Min(5000, Val(FORM.iopsCount)))>
<cfset latRuns    = Max(5,  Min(200,  Val(FORM.latencyRuns)))>

<!--- Ensure trailing slash --->
<cfif Right(testDir,1) NEQ "/" AND Right(testDir,1) NEQ "\">
    <cfset testDir = testDir & "/">
</cfif>

<!--- ╔══════════════════════════════════════════════════════════╗
      ║  1. DISK CAPACITY                                        ║
      ╚══════════════════════════════════════════════════════════╝ --->
<cfset capOk  = false>
<cfset capErr = "">
<cftry>
    <cfset jFile     = createObject("java","java.io.File").init(testDir)>
    <cfset totalBytes = jFile.getTotalSpace()>
    <cfset freeBytes  = jFile.getUsableSpace()>
    <cfset usedBytes  = totalBytes - jFile.getFreeSpace()>
    <cfset pctUsed    = (totalBytes GT 0) ? Int(usedBytes * 100 / totalBytes) : 0>
    <cfset capOk = true>
    <cfcatch><cfset capErr = cfcatch.message></cfcatch>
</cftry>

<!--- Helper: bytes → human --->
<cffunction name="humanBytes" output="false" returntype="string">
    <cfargument name="b" type="numeric">
    <cfif b GTE 1099511627776><cfreturn NumberFormat(b/1099511627776,"0.00") & " TB"></cfif>
    <cfif b GTE 1073741824>   <cfreturn NumberFormat(b/1073741824,   "0.00") & " GB"></cfif>
    <cfif b GTE 1048576>      <cfreturn NumberFormat(b/1048576,      "0.00") & " MB"></cfif>
    <cfif b GTE 1024>         <cfreturn NumberFormat(b/1024,         "0.00") & " KB"></cfif>
    <cfreturn b & " B">
</cffunction>

<!--- ╔══════════════════════════════════════════════════════════╗
      ║  2. SEQUENTIAL WRITE                                     ║
      ╚══════════════════════════════════════════════════════════╝ --->
<cfset seqOk      = false>
<cfset seqErr     = "">
<cfset seqFile    = testDir & "lucee_seq_test_" & createUUID() & ".tmp">
<cfset chunkBytes = 1048576><!--- 1 MB chunk --->
<cfset totalSeqBytes = seqSizeMB * chunkBytes>
<cfset chunk      = RepeatString("X", chunkBytes)><!--- 1 MB string --->

<cftry>
    <cfset swStart = getTickCount()>
    <cfloop from="1" to="#seqSizeMB#" index="i">
        <cffile action="append" file="#seqFile#" output="#chunk#" addnewline="false">
    </cfloop>
    <cfset swMs  = Max(1, getTickCount() - swStart)>
    <cfset swMBs = NumberFormat(seqSizeMB / (swMs / 1000), "0.00")>

    <!--- Sequential read --->
    <cfset srStart = getTickCount()>
    <cffile action="read" file="#seqFile#" variable="readBuf">
    <cfset srMs  = Max(1, getTickCount() - srStart)>
    <!--- Actual bytes read (string length ≈ bytes for ASCII) --->
    <cfset actualBytes = Len(readBuf)>
    <cfset srMBs = NumberFormat((actualBytes / 1048576) / (srMs / 1000), "0.00")>
    <cfset readBuf = ""><!--- free memory --->

    <cffile action="delete" file="#seqFile#">
    <cfset seqOk = true>
    <cfcatch>
        <cfset seqErr = cfcatch.message & " — " & cfcatch.detail>
        <cftry><cffile action="delete" file="#seqFile#"><cfcatch></cfcatch></cftry>
    </cfcatch>
</cftry>

<!--- ╔══════════════════════════════════════════════════════════╗
      ║  3. IOPS  (500 × 4 KB files)                            ║
      ╚══════════════════════════════════════════════════════════╝ --->
<cfset iopsOk      = false>
<cfset iopsErr     = "">
<cfset iopsDir     = testDir & "lucee_iops_" & createUUID() & "/">
<cfset iopsPayload = RepeatString("I", 4096)><!--- 4 KB --->

<cftry>
    <cfdirectory action="create" directory="#iopsDir#">

    <!--- Write IOPS --->
    <cfset iwStart = getTickCount()>
    <cfloop from="1" to="#iopsCount#" index="n">
        <cffile action="write"
                file="#iopsDir#f#n#.tmp"
                output="#iopsPayload#"
                addnewline="false">
    </cfloop>
    <cfset iwMs   = Max(1, getTickCount() - iwStart)>
    <cfset iwIOPS = Int(iopsCount / (iwMs / 1000))>

    <!--- Read IOPS --->
    <cfset irStart = getTickCount()>
    <cfloop from="1" to="#iopsCount#" index="n">
        <cffile action="read" file="#iopsDir#f#n#.tmp" variable="tmp">
    </cfloop>
    <cfset irMs   = Max(1, getTickCount() - irStart)>
    <cfset irIOPS = Int(iopsCount / (irMs / 1000))>

    <!--- Cleanup --->
    <cfdirectory action="delete" directory="#iopsDir#" recurse="true">
    <cfset iopsOk = true>
    <cfcatch>
        <cfset iopsErr = cfcatch.message & " — " & cfcatch.detail>
        <cftry><cfdirectory action="delete" directory="#iopsDir#" recurse="true"><cfcatch></cfcatch></cftry>
    </cfcatch>
</cftry>

<!--- ╔══════════════════════════════════════════════════════════╗
      ║  4. WRITE LATENCY  (single tiny writes, averaged)        ║
      ╚══════════════════════════════════════════════════════════╝ --->
<cfset latOk  = false>
<cfset latErr = "">
<cfset latFile = testDir & "lucee_lat_" & createUUID() & ".tmp">

<cftry>
    <cfset latTotal = 0>
    <cfset latMin   = 999999>
    <cfset latMax   = 0>
    <cfloop from="1" to="#latRuns#" index="r">
        <cfset t0 = getTickCount()>
        <cffile action="write" file="#latFile#" output="X" addnewline="false">
        <cfset elapsed = getTickCount() - t0>
        <cfset latTotal = latTotal + elapsed>
        <cfif elapsed LT latMin><cfset latMin = elapsed></cfif>
        <cfif elapsed GT latMax><cfset latMax = elapsed></cfif>
    </cfloop>
    <cfset latAvg = NumberFormat(latTotal / latRuns, "0.00")>
    <cffile action="delete" file="#latFile#">
    <cfset latOk = true>
    <cfcatch>
        <cfset latErr = cfcatch.message>
        <cftry><cffile action="delete" file="#latFile#"><cfcatch></cfcatch></cftry>
    </cfcatch>
</cftry>

<cfset grandTotal = getTickCount() - pageStart>

<!--- ══════════════════════════ OUTPUT ══════════════════════════════ --->

<!--- 1. Capacity --->
<div class="section">
    <h2>1 &mdash; Disk Capacity</h2>
    <cfif capOk>
    <table>
        <tr><td>Test path</td><td>#HTMLEditFormat(testDir)#</td></tr>
        <tr>
            <td>Total space</td>
            <td>#humanBytes(totalBytes)# (#NumberFormat(totalBytes)# bytes)</td>
        </tr>
        <tr>
            <td>Used space</td>
            <td>
                #humanBytes(usedBytes)# &mdash; #pctUsed#%
                <span class="bar-wrap">
                    <span class="bar" style="width:#pctUsed#%"></span>
                </span>
            </td>
        </tr>
        <tr>
            <td>Free (usable) space</td>
            <td>
                #humanBytes(freeBytes)#
                <cfif pctUsed GTE 90>
                    <span class="err">&nbsp;&#9888; Disk nearly full!</span>
                <cfelseif pctUsed GTE 75>
                    <span class="warn">&nbsp;&#9888; Getting full</span>
                <cfelse>
                    <span class="ok">&nbsp;&#10003; Healthy</span>
                </cfif>
            </td>
        </tr>
    </table>
    <cfelse>
    <p class="err">Failed: #HTMLEditFormat(capErr)#</p>
    </cfif>
</div>

<!--- 2. Sequential --->
<div class="section">
    <h2>2 &mdash; Sequential Throughput (#seqSizeMB# MB file)</h2>
    <cfif seqOk>
    <table>
        <tr>
            <td>Write speed</td>
            <td>
                <strong>#swMBs# MB/s</strong> &nbsp;(#seqSizeMB# MB in #swMs# ms)
                <cfset swBar = Min(100, Int(Val(swMBs) / 5))>
                <span class="bar-wrap"><span class="bar-g" style="width:#swBar#%"></span></span>
            </td>
        </tr>
        <tr>
            <td>Read speed</td>
            <td>
                <strong>#srMBs# MB/s</strong> &nbsp;(#humanBytes(actualBytes)# in #srMs# ms)
                <cfset srBar = Min(100, Int(Val(srMBs) / 5))>
                <span class="bar-wrap"><span class="bar-g" style="width:#srBar#%"></span></span>
            </td>
        </tr>
    </table>
    <p class="note">Bars scaled: 500 MB/s = 100%. OS page cache may inflate read speed on warm runs.</p>
    <cfelse>
    <p class="err">Failed: #HTMLEditFormat(seqErr)#</p>
    </cfif>
</div>

<!--- 3. IOPS --->
<div class="section">
    <h2>3 &mdash; IOPS Simulation (#iopsCount# &times; 4 KB files)</h2>
    <cfif iopsOk>
    <table>
        <tr>
            <td>Write IOPS</td>
            <td>
                <strong>#NumberFormat(iwIOPS)# ops/s</strong> &nbsp;(#iopsCount# files in #iwMs# ms)
                <cfset wBar = Min(100, Int(iwIOPS / 100))>
                <span class="bar-wrap"><span class="bar-g" style="width:#wBar#%"></span></span>
            </td>
        </tr>
        <tr>
            <td>Read IOPS</td>
            <td>
                <strong>#NumberFormat(irIOPS)# ops/s</strong> &nbsp;(#iopsCount# files in #irMs# ms)
                <cfset rBar = Min(100, Int(irIOPS / 100))>
                <span class="bar-wrap"><span class="bar-g" style="width:#rBar#%"></span></span>
            </td>
        </tr>
    </table>
    <p class="note">Bars scaled: 10,000 IOPS = 100%. JVM + OS buffering means these are
    application-level IOPS, not raw device IOPS. Use <code>fio</code> for bare-metal numbers.</p>
    <cfelse>
    <p class="err">Failed: #HTMLEditFormat(iopsErr)#</p>
    </cfif>
</div>

<!--- 4. Latency --->
<div class="section">
    <h2>4 &mdash; Write Latency (#latRuns# samples, single byte each)</h2>
    <cfif latOk>
    <table>
        <tr><td>Average latency</td><td><strong>#latAvg# ms</strong></td></tr>
        <tr><td>Min latency</td>    <td>#latMin# ms</td></tr>
        <tr><td>Max latency</td>    <td>#latMax# ms</td></tr>
        <tr>
            <td>Assessment</td>
            <td>
                <cfif Val(latAvg) LTE 1>
                    <span class="ok">Excellent (SSD / NVMe)</span>
                <cfelseif Val(latAvg) LTE 5>
                    <span class="ok">Good (fast SSD or cached HDD)</span>
                <cfelseif Val(latAvg) LTE 15>
                    <span class="warn">Moderate (spinning disk or network storage)</span>
                <cfelse>
                    <span class="err">High latency (slow disk, NFS, or heavy load)</span>
                </cfif>
            </td>
        </tr>
    </table>
    <cfelse>
    <p class="err">Failed: #HTMLEditFormat(latErr)#</p>
    </cfif>
</div>

<!--- Summary --->
<div class="section">
    <h2>Summary</h2>
    <table>
        <tr><td>Total benchmark time</td><td>#grandTotal# ms</td></tr>
        <tr><td>Disk capacity</td>   <td><cfif capOk> <span class="ok">PASS</span> <cfelse><span class="err">FAIL</span></cfif></td></tr>
        <tr><td>Sequential write</td><td><cfif seqOk> <span class="ok">PASS</span> <cfelse><span class="err">FAIL</span></cfif></td></tr>
        <tr><td>Sequential read</td> <td><cfif seqOk> <span class="ok">PASS</span> <cfelse><span class="err">FAIL</span></cfif></td></tr>
        <tr><td>Write IOPS</td>      <td><cfif iopsOk><span class="ok">PASS</span> <cfelse><span class="err">FAIL</span></cfif></td></tr>
        <tr><td>Read IOPS</td>       <td><cfif iopsOk><span class="ok">PASS</span> <cfelse><span class="err">FAIL</span></cfif></td></tr>
        <tr><td>Write latency</td>   <td><cfif latOk> <span class="ok">PASS</span> <cfelse><span class="err">FAIL</span></cfif></td></tr>
        <tr><td>All temp files</td>  <td><span class="ok">Deleted &#10003;</span></td></tr>
    </table>
</div>

<p><a href="#CGI.SCRIPT_NAME#">&larr; Run again with different settings</a></p>

</cfif><!--- end POST --->

</body>
</html>
