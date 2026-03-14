<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Lucee Test Suite</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: monospace; background: #f0f2f5; min-height: 100vh; padding: 40px 20px; }
        h1   { font-size: 1.4rem; margin-bottom: 6px; }
        .sub { color: #666; font-size: .9rem; margin-bottom: 32px; }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 18px;
            max-width: 900px;
        }
        .card {
            background: #fff;
            border: 1px solid #ddd;
            border-radius: 6px;
            padding: 20px;
            text-decoration: none;
            color: inherit;
            display: block;
            transition: box-shadow .15s, border-color .15s;
        }
        .card:hover { box-shadow: 0 4px 14px rgba(0,0,0,.1); border-color: #4a90d9; }
        .icon { font-size: 2rem; margin-bottom: 10px; }
        .card h2 { font-size: 1rem; margin-bottom: 6px; }
        .card p  { font-size: .83rem; color: #555; line-height: 1.5; }
        .badge {
            display: inline-block;
            font-size: .72rem;
            padding: 2px 7px;
            border-radius: 10px;
            margin-top: 10px;
            font-weight: bold;
        }
        .b-blue   { background: #e3f0ff; color: #1a6ac7; }
        .b-green  { background: #e3f7e8; color: #1a7a35; }
        .b-orange { background: #fff3e0; color: #b35c00; }
        .b-red    { background: #fde8e8; color: #b30000; }
        .b-purple { background: #f0e8ff; color: #6a00cc; }
        footer { max-width: 900px; margin-top: 36px; font-size: .8rem; color: #999; }
    </style>
</head>
<body>

<h1>Lucee Test Suite</h1>
<p class="sub">
    Lucee <cfoutput>#server.lucee.version#</cfoutput> &nbsp;|&nbsp;
    Java <cfoutput>#server.java.version#</cfoutput> &nbsp;|&nbsp;
    <cfoutput>#DateTimeFormat(now(),"yyyy-mm-dd HH:nn:ss")#</cfoutput>
</p>

<div class="grid">

    <a class="card" href="load_time_test.cfm">
        <div class="icon">&#9201;</div>
        <h2>Page Load Time Test</h2>
        <p>Set a minimum page duration in ms. The server measures elapsed time, sleeps for the remainder, and shows a full timing breakdown.</p>
        <span class="badge b-blue">Performance</span>
    </a>

    <a class="card" href="file_upload_test.cfm">
        <div class="icon">&#128229;</div>
        <h2>File Upload Test</h2>
        <p>Upload any file (including large ones) to verify Lucee can receive it. Shows file size, MIME type, upload duration, throughput, and cleans up after.</p>
        <span class="badge b-green">Upload</span>
    </a>

    <a class="card" href="disk_test.cfm">
        <div class="icon">&#128190;</div>
        <h2>Disk Benchmark</h2>
        <p>Four tests in one: disk capacity &amp; free space, sequential read/write MB/s, IOPS simulation (4 KB files), and write latency with SSD/HDD classification.</p>
        <span class="badge b-orange">Disk I/O</span>
    </a>

    <a class="card" href="lucee_diag.cfm">
        <div class="icon">&#128269;</div>
        <h2>Lucee Diagnostics</h2>
        <p>Full root-cause analyser: JVM heap, GC pressure, thread deadlocks, CPU load, datasource connectivity, scope sizes, and a checklist with fix guidance.</p>
        <span class="badge b-red">Diagnostics</span>
    </a>

    <a class="card" href="probe.cfm">
        <div class="icon">&#128268;</div>
        <h2>Health Probe (JSON)</h2>
        <p>Lightweight JSON endpoint for UptimeRobot, Pingdom, Zabbix, or load balancers. Returns HTTP 200 (ok/degraded) or HTTP 503 (critical) in under 15 ms.</p>
        <span class="badge b-purple">Monitoring</span>
    </a>

</div>

<footer>
    All test files write to the Lucee temp directory and clean up after themselves. &nbsp;|&nbsp;
    <a href="monitoring_setup.md">Monitoring setup guide</a>
</footer>

</body>
</html>
