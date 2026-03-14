<!---
    Lucee Diagnostic Page
    Checks: JVM memory, GC pressure, thread health, CPU load,
            deadlocks, datasource pools, Lucee caches, session/app
            counts, OS resources, temp disk space, and slow-request hints.
--->
<cfset t0 = getTickCount()>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Lucee Diagnostics</title>
    <style>
        body  { font-family: monospace; max-width: 860px; margin: 30px auto; padding: 0 18px; }
        h1    { font-size: 1.3rem; }
        h2    { font-size: 1rem; margin: 26px 0 6px;
                border-bottom: 2px solid #ccc; padding-bottom: 4px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 4px; }
        td    { padding: 5px 8px; vertical-align: top; }
        td:first-child { width: 240px; font-weight: bold; color: #444; white-space: nowrap; }
        .card { background: #f7f7f7; border-radius: 4px; padding: 14px 16px; margin-bottom: 18px; }
        .ok   { color: #2a9d2a; font-weight: bold; }
        .warn { color: #e07b00; font-weight: bold; }
        .err  { color: #cc0000; font-weight: bold; }
        .bar-wrap { display:inline-block; vertical-align:middle;
                    width:180px; height:12px; background:#ddd;
                    border-radius:3px; margin-left:6px; }
        .bar  { height:12px; border-radius:3px; }
        .bg   { background:#2a9d2a; }
        .bw   { background:#e07b00; }
        .be   { background:#cc0000; }
        .note { font-size:.82rem; color:#666; margin-top:5px; }
        pre   { background:#fff; border:1px solid #ccc; padding:10px;
                overflow:auto; font-size:.8rem; max-height:260px; }
        .grid { display:grid; grid-template-columns:1fr 1fr; gap:0 28px; }
        a.refresh { font-size:.9rem; }
    </style>
</head>
<body>

<h1>Lucee Diagnostics &mdash; <cfoutput>#DateTimeFormat(now(),"yyyy-mm-dd HH:nn:ss")#</cfoutput></h1>
<p><a class="refresh" href="#CGI.SCRIPT_NAME#">&#8635; Refresh</a> &nbsp;|&nbsp;
   Auto-refresh:
   <a href="#CGI.SCRIPT_NAME#?r=5">5s</a> &nbsp;
   <a href="#CGI.SCRIPT_NAME#?r=30">30s</a></p>

<cfif Val(URL.r) GT 0>
    <cfset safeR = Min(300, Val(URL.r))>
    <meta http-equiv="refresh" content="#safeR#">
    <p class="note">Auto-refreshing every #safeR# seconds.</p>
</cfif>

<!---
    ╔══════════════════════════════════════════════════════════════╗
    ║  HELPER: traffic-light label                                 ║
    ╚══════════════════════════════════════════════════════════════╝
--->
<cffunction name="light" output="false" returntype="string">
    <cfargument name="pct"  type="numeric">
    <cfargument name="wThresh" type="numeric" default="70">
    <cfargument name="eThresh" type="numeric" default="90">
    <cfif pct GTE eThresh><cfreturn "err"></cfif>
    <cfif pct GTE wThresh><cfreturn "warn"></cfif>
    <cfreturn "ok">
</cffunction>

<cffunction name="barHTML" output="false" returntype="string">
    <cfargument name="pct"   type="numeric">
    <cfargument name="label" type="string" default="">
    <cfset cls = light(pct)>
    <cfset col = (cls EQ "ok") ? "bg" : ((cls EQ "warn") ? "bw" : "be")>
    <cfreturn '<span class="bar-wrap"><span class="bar #col#" style="width:#pct#%"></span></span>
               <span class="#cls#">#pct#%</span> #label#'>
</cffunction>

<!---
    ╔══════════════════════════════════════════════════════════════╗
    ║  1. LUCEE / SERVER INFO                                      ║
    ╚══════════════════════════════════════════════════════════════╝
--->
<div class="card">
<h2>1 &mdash; Server Info</h2>
<table>
    <tr><td>Lucee version</td>      <td>#server.lucee.version#</td></tr>
    <tr><td>Java version</td>       <td>#server.java.version#</td></tr>
    <tr><td>OS</td>                 <td>#server.os.name# #server.os.version# (#server.os.arch#)</td></tr>
    <tr><td>Hostname</td>           <td>#CGI.SERVER_NAME#</td></tr>
    <tr><td>Servlet container</td>  <td>#server.servlet.name#</td></tr>
    <tr><td>Diag page load time</td><td id="pageMs">calculating...</td></tr>
</table>
</div>

<!---
    ╔══════════════════════════════════════════════════════════════╗
    ║  2. JVM MEMORY                                               ║
    ╚══════════════════════════════════════════════════════════════╝
--->
<cfset rt        = createObject("java","java.lang.Runtime").getRuntime()>
<cfset maxMem    = rt.maxMemory()>
<cfset totalMem  = rt.totalMemory()>
<cfset freeMem   = rt.freeMemory()>
<cfset usedMem   = totalMem - freeMem>
<cfset heapPct   = (maxMem GT 0) ? Int(usedMem * 100 / maxMem) : 0>

<cffunction name="mb" output="false" returntype="string">
    <cfargument name="b" type="numeric">
    <cfreturn NumberFormat(b / 1048576, "0") & " MB">
</cffunction>

<div class="card">
<h2>2 &mdash; JVM Heap Memory</h2>
<table>
    <tr>
        <td>Heap used / max</td>
        <td>#mb(usedMem)# / #mb(maxMem)#
            #barHTML(heapPct)#
        </td>
    </tr>
    <tr>
        <td>Heap committed</td>
        <td>#mb(totalMem)#</td>
    </tr>
    <tr>
        <td>Heap free</td>
        <td>#mb(freeMem)#</td>
    </tr>
    <cfif heapPct GTE 90>
    <tr>
        <td>&#9888; Risk</td>
        <td class="err">Heap &gt;90% — OutOfMemoryError likely. Increase -Xmx or find memory leak.</td>
    </tr>
    <cfelseif heapPct GTE 70>
    <tr>
        <td>&#9888; Warning</td>
        <td class="warn">Heap &gt;70% — GC pressure may be slowing Lucee. Monitor closely.</td>
    </tr>
    </cfif>
</table>
<p class="note">Tip: set -Xms == -Xmx to avoid heap resize pauses. Recommended minimum: 512 MB.</p>
</div>

<!---
    ╔══════════════════════════════════════════════════════════════╗
    ║  3. GARBAGE COLLECTION                                       ║
    ╚══════════════════════════════════════════════════════════════╝
--->
<cftry>
<cfset mxFactory  = createObject("java","java.lang.management.ManagementFactory")>
<cfset gcBeans    = mxFactory.getGarbageCollectorMXBeans()>
<cfset gcTotalMs  = 0>
<cfset gcTotalCnt = 0>
<cfloop array="#gcBeans#" item="gc">
    <cfset gcTotalMs  = gcTotalMs  + Max(0, gc.getCollectionTime())>
    <cfset gcTotalCnt = gcTotalCnt + Max(0, gc.getCollectionCount())>
</cfloop>

<div class="card">
<h2>3 &mdash; Garbage Collection</h2>
<table>
    <cfloop array="#gcBeans#" item="gc">
    <tr>
        <td>#gc.getName()#</td>
        <td>
            Collections: <strong>#Max(0,gc.getCollectionCount())#</strong> &nbsp;|&nbsp;
            Total time: <strong>#Max(0,gc.getCollectionTime())# ms</strong>
        </td>
    </tr>
    </cfloop>
    <tr><td>All GC total time</td><td><strong>#gcTotalMs# ms</strong></td></tr>
    <tr>
        <td>Assessment</td>
        <td>
            <cfif gcTotalMs GT 60000>
                <span class="err">&#9888; &gt;60s in GC — severe GC pressure, JVM likely pausing frequently.</span>
            <cfelseif gcTotalMs GT 10000>
                <span class="warn">&#9888; &gt;10s in GC — moderate pressure. Check heap sizing.</span>
            <cfelse>
                <span class="ok">&#10003; GC time normal.</span>
            </cfif>
        </td>
    </tr>
</table>
<p class="note">High GC time = Lucee stops the world. Fix: increase -Xmx, reduce cache sizes, fix memory leaks.</p>
</div>
<cfcatch>
<div class="card"><h2>3 &mdash; Garbage Collection</h2>
<p class="warn">Could not read GC beans: #HTMLEditFormat(cfcatch.message)#</p>
</div>
</cfcatch>
</cftry>

<!---
    ╔══════════════════════════════════════════════════════════════╗
    ║  4. THREADS                                                  ║
    ╚══════════════════════════════════════════════════════════════╝
--->
<cftry>
<cfset threadBean    = mxFactory.getThreadMXBean()>
<cfset threadCount   = threadBean.getThreadCount()>
<cfset peakThreads   = threadBean.getPeakThreadCount()>
<cfset daemonThreads = threadBean.getDaemonThreadCount()>
<cfset deadlocked    = threadBean.findDeadlockedThreads()>
<cfset deadlockCount = IsNull(deadlocked) ? 0 : ArrayLen(deadlocked)>

<div class="card">
<h2>4 &mdash; JVM Threads</h2>
<table>
    <tr><td>Active threads</td>  <td><strong>#threadCount#</strong></td></tr>
    <tr><td>Daemon threads</td>  <td>#daemonThreads#</td></tr>
    <tr><td>Peak threads</td>    <td>#peakThreads#</td></tr>
    <tr>
        <td>Deadlocked threads</td>
        <td>
            <cfif deadlockCount GT 0>
                <span class="err">&#9888; #deadlockCount# DEADLOCK(S) DETECTED — restart required!</span>
            <cfelse>
                <span class="ok">&#10003; None</span>
            </cfif>
        </td>
    </tr>
    <tr>
        <td>Thread count assessment</td>
        <td>
            <cfif threadCount GT 500>
                <span class="err">&#9888; &gt;500 threads — thread pool exhaustion likely. Check slow DB queries or blocked I/O.</span>
            <cfelseif threadCount GT 200>
                <span class="warn">&#9888; &gt;200 threads — elevated. Watch for spikes.</span>
            <cfelse>
                <span class="ok">&#10003; Normal</span>
            </cfif>
        </td>
    </tr>
</table>
<p class="note">Deadlocks = Lucee hangs completely. High thread count = connection pool exhaustion or slow queries backing up.</p>
</div>
<cfcatch>
<div class="card"><h2>4 &mdash; Threads</h2>
<p class="warn">Could not read thread info: #HTMLEditFormat(cfcatch.message)#</p>
</div>
</cfcatch>
</cftry>

<!---
    ╔══════════════════════════════════════════════════════════════╗
    ║  5. CPU / OS LOAD                                            ║
    ╚══════════════════════════════════════════════════════════════╝
--->
<cftry>
<cfset osMxBean    = mxFactory.getOperatingSystemMXBean()>
<cfset loadAvg     = osMxBean.getSystemLoadAverage()>
<cfset cpuCount    = osMxBean.getAvailableProcessors()>
<cfset archName    = osMxBean.getArch()>
<cfset loadPerCore = (cpuCount GT 0 AND loadAvg GT 0) ? NumberFormat(loadAvg / cpuCount,"0.00") : "N/A">

<!--- Try com.sun.management extended bean for process CPU --->
<cfset procCpuPct = -1>
<cftry>
    <cfset sunBean   = createObject("java","com.sun.management.OperatingSystemMXBean")>
    <cfset sunBean   = mxFactory.getOperatingSystemMXBean()>
    <cfset procCpuPct = Int(sunBean.getProcessCpuLoad() * 100)>
<cfcatch></cfcatch>
</cftry>

<div class="card">
<h2>5 &mdash; CPU &amp; OS Load</h2>
<table>
    <tr><td>CPU cores</td>         <td>#cpuCount# (#archName#)</td></tr>
    <tr>
        <td>System load average</td>
        <td>
            <strong>#NumberFormat(loadAvg,"0.00")#</strong>
            (per core: #loadPerCore#)
            <cfif loadAvg GT cpuCount>
                <span class="err"> &#9888; Overloaded! Load &gt; core count.</span>
            <cfelseif loadAvg GT cpuCount * 0.7>
                <span class="warn"> &#9888; High load.</span>
            <cfelse>
                <span class="ok"> &#10003; Normal</span>
            </cfif>
        </td>
    </tr>
    <cfif procCpuPct GTE 0>
    <tr>
        <td>JVM process CPU</td>
        <td>#barHTML(procCpuPct)#</td>
    </tr>
    </cfif>
</table>
<p class="note">Load &gt; core count means the CPU queue is building up — requests will slow down.</p>
</div>
<cfcatch>
<div class="card"><h2>5 &mdash; CPU / OS Load</h2>
<p class="warn">Could not read OS bean: #HTMLEditFormat(cfcatch.message)#</p>
</div>
</cfcatch>
</cftry>

<!---
    ╔══════════════════════════════════════════════════════════════╗
    ║  6. TEMP DISK SPACE                                          ║
    ╚══════════════════════════════════════════════════════════════╝
--->
<cftry>
<cfset jTmp     = createObject("java","java.io.File").init(getTempDirectory())>
<cfset tmpFree  = jTmp.getUsableSpace()>
<cfset tmpTotal = jTmp.getTotalSpace()>
<cfset tmpPct   = (tmpTotal GT 0) ? Int((tmpTotal - tmpFree) * 100 / tmpTotal) : 0>

<div class="card">
<h2>6 &mdash; Temp Disk Space</h2>
<table>
    <tr><td>Temp directory</td>  <td>#HTMLEditFormat(getTempDirectory())#</td></tr>
    <tr>
        <td>Disk used</td>
        <td>#barHTML(tmpPct)#
            &nbsp;(#NumberFormat(tmpFree/1073741824,"0.00")# GB free
             of #NumberFormat(tmpTotal/1073741824,"0.00")# GB)
        </td>
    </tr>
    <cfif tmpFree LT 104857600><!--- less than 100 MB --->
    <tr>
        <td>&#9888; Critical</td>
        <td class="err">Less than 100 MB free! File uploads, session storage, and logging will fail.</td>
    </tr>
    </cfif>
</table>
</div>
<cfcatch>
<div class="card"><h2>6 &mdash; Temp Disk</h2>
<p class="warn">Could not read disk: #HTMLEditFormat(cfcatch.message)#</p>
</div>
</cfcatch>
</cftry>

<!---
    ╔══════════════════════════════════════════════════════════════╗
    ║  7. DATASOURCES — ping each configured datasource            ║
    ╚══════════════════════════════════════════════════════════════╝
--->
<div class="card">
<h2>7 &mdash; Datasource Connectivity</h2>
<cfset dsNames = structKeyList(server.datasources ?: {})>
<cfif Len(Trim(dsNames)) EQ 0>
    <p class="note">No datasources configured in server scope (or not exposed).
    To test manually, add <code>this.datasources</code> in Application.cfc.</p>
<cfelse>
<table>
<cfloop list="#dsNames#" item="dsName">
    <cftry>
        <cfset dsT0 = getTickCount()>
        <cfquery name="dsTest" datasource="#dsName#" maxrows="1" timeout="5">
            SELECT 1
        </cfquery>
        <cfset dsMs = getTickCount() - dsT0>
        <tr>
            <td>#HTMLEditFormat(dsName)#</td>
            <td>
                <span class="ok">&#10003; Connected</span>
                &nbsp;(#dsMs# ms)
                <cfif dsMs GT 1000>
                    <span class="warn"> &#9888; Slow query!</span>
                </cfif>
            </td>
        </tr>
    <cfcatch>
        <tr>
            <td>#HTMLEditFormat(dsName)#</td>
            <td><span class="err">&#10007; FAILED: #HTMLEditFormat(cfcatch.message)#</span></td>
        </tr>
    </cfcatch>
    </cftry>
</cfloop>
</table>
</cfif>
<p class="note">DB connection failure = slow/hanging requests. Check connection pool max size in Lucee admin.</p>
</div>

<!---
    ╔══════════════════════════════════════════════════════════════╗
    ║  8. SESSION / APPLICATION SCOPE SIZES                        ║
    ╚══════════════════════════════════════════════════════════════╝
--->
<div class="card">
<h2>8 &mdash; Scopes &amp; Request</h2>
<table>
    <tr>
        <td>Application scope keys</td>
        <td>#StructCount(application)#</td>
    </tr>
    <tr>
        <td>Session scope keys</td>
        <td>
            <cfif IsDefined("session")>
                #StructCount(session)#
            <cfelse>
                <span class="note">Session not enabled for this page</span>
            </cfif>
        </td>
    </tr>
    <tr>
        <td>Request scope keys</td>
        <td>#StructCount(request)#</td>
    </tr>
    <tr>
        <td>CGI CONTENT_LENGTH</td>
        <td>#Val(CGI.CONTENT_LENGTH)# bytes</td>
    </tr>
</table>
<p class="note">Huge application scope = more GC pressure. Bloated session = slow session serialisation.</p>
</div>

<!---
    ╔══════════════════════════════════════════════════════════════╗
    ║  9. LUCEE TEMPLATE CACHE                                     ║
    ╚══════════════════════════════════════════════════════════════╝
--->
<cftry>
<cfset cacheInfo = cacheGetSession()>
<div class="card">
<h2>9 &mdash; Lucee Template / Object Cache</h2>
<cfif IsStruct(cacheInfo)>
<table>
    <cfloop collection="#cacheInfo#" item="k">
    <tr><td>#HTMLEditFormat(k)#</td><td>#HTMLEditFormat(ToString(cacheInfo[k]))#</td></tr>
    </cfloop>
</table>
<cfelse>
    <p class="note">Cache session info not available at application level (requires Lucee admin context).</p>
</cfif>
</div>
<cfcatch>
<div class="card"><h2>9 &mdash; Template Cache</h2>
<p class="note">Cache stats not accessible from this context. Check Lucee Server Admin &rarr; Cache.</p>
</div>
</cfcatch>
</cftry>

<!---
    ╔══════════════════════════════════════════════════════════════╗
    ║  10. COMMON ROOT CAUSE CHECKLIST                             ║
    ╚══════════════════════════════════════════════════════════════╝
--->
<div class="card">
<h2>10 &mdash; Common Root Cause Checklist</h2>
<table>
    <tr>
        <td>JVM heap &gt; 90%</td>
        <td><cfif heapPct GTE 90><span class="err">&#9888; YES — increase -Xmx</span><cfelse><span class="ok">&#10003; No</span></cfif></td>
    </tr>
    <tr>
        <td>Deadlocked threads</td>
        <td><cfif deadlockCount GT 0><span class="err">&#9888; YES — restart JVM</span><cfelse><span class="ok">&#10003; No</span></cfif></td>
    </tr>
    <tr>
        <td>Thread count &gt; 500</td>
        <td><cfif threadCount GT 500><span class="err">&#9888; YES — check DB/IO blocking</span><cfelse><span class="ok">&#10003; No (#threadCount#)</span></cfif></td>
    </tr>
    <tr>
        <td>CPU overloaded</td>
        <td><cfif loadAvg GT cpuCount><span class="err">&#9888; YES — load #NumberFormat(loadAvg,"0.00")# on #cpuCount# cores</span><cfelse><span class="ok">&#10003; No</span></cfif></td>
    </tr>
    <tr>
        <td>Disk nearly full</td>
        <td><cfif tmpPct GTE 90><span class="err">&#9888; YES — free up disk space</span><cfelse><span class="ok">&#10003; No (#tmpPct#%)</span></cfif></td>
    </tr>
    <tr>
        <td>GC time excessive</td>
        <td><cfif gcTotalMs GT 60000><span class="err">&#9888; YES — #gcTotalMs# ms</span><cfelseif gcTotalMs GT 10000><span class="warn">&#9888; Elevated — #gcTotalMs# ms</span><cfelse><span class="ok">&#10003; No</span></cfif></td>
    </tr>
</table>

<h2 style="margin-top:16px; border:none; font-size:.95rem;">What to do next per symptom</h2>
<table>
    <tr>
        <td>Lucee totally unresponsive</td>
        <td>Check deadlocks above. If found, restart. Otherwise check thread count — DB pool exhaustion is #1 cause.</td>
    </tr>
    <tr>
        <td>Lucee very slow, not down</td>
        <td>Check heap %, GC time, CPU load. High heap → GC pauses freeze JVM. High CPU → infinite loop or tight query.</td>
    </tr>
    <tr>
        <td>Random slowness</td>
        <td>Check DB connectivity and ping time. A slow datasource blocks all threads waiting on that connection.</td>
    </tr>
    <tr>
        <td>Slow after uptime grows</td>
        <td>Memory leak — heap % climbs over time. Add <code>-verbose:gc</code> to JVM args and watch GC logs.</td>
    </tr>
    <tr>
        <td>Slow only for some requests</td>
        <td>Template compilation cache full or cold. Check Lucee Admin &rarr; Performance / Caches.</td>
    </tr>
    <tr>
        <td>File uploads / sessions failing</td>
        <td>Check temp disk free space above.</td>
    </tr>
</table>
</div>

<!--- Page load time inject via JS --->
<cfset diagMs = getTickCount() - t0>
<script>
    document.getElementById("pageMs").textContent = "#diagMs# ms";
</script>

<p class="note">Diagnostic page itself took #diagMs# ms to render.</p>
<p><a href="#CGI.SCRIPT_NAME#">&larr; Refresh</a></p>

</body>
</html>
