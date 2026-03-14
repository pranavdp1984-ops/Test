<!---
    Lucee Health Probe — lightweight JSON endpoint
    Use this URL in UptimeRobot / Pingdom / Zabbix / load balancer.
    Returns HTTP 200 (healthy) or HTTP 503 (unhealthy) + JSON body.
    Designed to be FAST — no DB, no disk writes, no heavy processing.
--->
<cfsilent>

<cfset t0 = getTickCount()>

<!--- ── Collect metrics ──────────────────────────────────────────── --->

<!--- JVM heap --->
<cfset rt       = createObject("java","java.lang.Runtime").getRuntime()>
<cfset maxMem   = rt.maxMemory()>
<cfset usedMem  = rt.totalMemory() - rt.freeMemory()>
<cfset heapPct  = (maxMem GT 0) ? Int(usedMem * 100 / maxMem) : 0>

<!--- Threads + deadlocks --->
<cfset threadBean     = createObject("java","java.lang.management.ManagementFactory").getThreadMXBean()>
<cfset threadCount    = threadBean.getThreadCount()>
<cfset deadlocked     = threadBean.findDeadlockedThreads()>
<cfset deadlockCount  = IsNull(deadlocked) ? 0 : ArrayLen(deadlocked)>

<!--- CPU load average --->
<cfset osMxBean  = createObject("java","java.lang.management.ManagementFactory").getOperatingSystemMXBean()>
<cfset loadAvg   = osMxBean.getSystemLoadAverage()>
<cfset cpuCount  = osMxBean.getAvailableProcessors()>

<!--- Disk (temp dir) --->
<cfset jTmp     = createObject("java","java.io.File").init(getTempDirectory())>
<cfset diskFree = jTmp.getUsableSpace()>   <!--- bytes --->

<!--- ── Decide status ───────────────────────────────────────────── --->
<!---
    CRITICAL  → return HTTP 503  (monitoring tool marks DOWN)
    DEGRADED  → return HTTP 200 with status=degraded (optional alert)
    OK        → return HTTP 200 with status=ok
--->
<cfset status  = "ok">
<cfset reasons = []>

<!--- Critical conditions --->
<cfif deadlockCount GT 0>
    <cfset status = "critical">
    <cfset ArrayAppend(reasons, "deadlock:#deadlockCount# thread(s)")>
</cfif>
<cfif heapPct GTE 95>
    <cfset status = "critical">
    <cfset ArrayAppend(reasons, "heap:#heapPct#pct")>
</cfif>
<cfif diskFree LT 52428800><!--- 50 MB --->
    <cfset status = "critical">
    <cfset ArrayAppend(reasons, "disk_free:#Int(diskFree/1048576)#MB")>
</cfif>

<!--- Degraded conditions (only if not already critical) --->
<cfif status NEQ "critical">
    <cfif heapPct GTE 80>
        <cfset status = "degraded">
        <cfset ArrayAppend(reasons, "heap:#heapPct#pct")>
    </cfif>
    <cfif threadCount GT 300>
        <cfset status = "degraded">
        <cfset ArrayAppend(reasons, "threads:#threadCount#")>
    </cfif>
    <cfif loadAvg GT cpuCount>
        <cfset status = "degraded">
        <cfset ArrayAppend(reasons, "load:#NumberFormat(loadAvg,'0.00')#/cpu:#cpuCount#")>
    </cfif>
</cfif>

<!--- ── HTTP status code ─────────────────────────────────────────── --->
<cfset httpCode = (status EQ "critical") ? 503 : 200>
<cfheader statuscode="#httpCode#"
           statustext="#(status EQ 'critical') ? 'Service Unavailable' : 'OK'#">

<!--- ── Build JSON response ─────────────────────────────────────── --->
<cfset probeMs = getTickCount() - t0>

<cfset payload = {
    "status"      : status,
    "http_code"   : httpCode,
    "timestamp"   : DateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ssXXX"),
    "probe_ms"    : probeMs,
    "lucee_version": server.lucee.version,
    "jvm" : {
        "heap_used_mb"  : Int(usedMem / 1048576),
        "heap_max_mb"   : Int(maxMem  / 1048576),
        "heap_pct"      : heapPct
    },
    "threads" : {
        "count"     : threadCount,
        "deadlocks" : deadlockCount
    },
    "cpu" : {
        "load_avg"  : NumberFormat(loadAvg, "0.00"),
        "cores"     : cpuCount
    },
    "disk" : {
        "temp_free_mb" : Int(diskFree / 1048576)
    },
    "reasons" : reasons
}>

</cfsilent><!--- end silent --->
<cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#SerializeJSON(payload)#</cfoutput>
