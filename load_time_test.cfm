<!---
    Lucee Load Time Test Page
    - Records the exact moment the page starts
    - Asks the user for a minimum page duration (in milliseconds)
    - Shows elapsed time and time remaining
    - Sleeps for whatever time is left to reach the minimum
--->
<cfset pageStart = getTickCount()>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Lucee Load Time Test</title>
    <style>
        body { font-family: monospace; max-width: 640px; margin: 40px auto; padding: 0 16px; }
        h1   { font-size: 1.3rem; }
        label { display: block; margin: 16px 0 4px; font-weight: bold; }
        input[type=number] { width: 160px; padding: 6px; font-size: 1rem; }
        button { margin-top: 12px; padding: 8px 20px; font-size: 1rem; cursor: pointer; }
        .result { margin-top: 24px; background: #f4f4f4; padding: 16px; border-radius: 4px; }
        .result table { border-collapse: collapse; width: 100%; }
        .result td { padding: 4px 8px; }
        .result td:first-child { font-weight: bold; white-space: nowrap; }
        .ok   { color: green; }
        .warn { color: orange; }
    </style>
</head>
<body>

<h1>Lucee Load-Time Test</h1>
<p>Enter the <strong>minimum</strong> number of milliseconds this page should take to load.
The server will sleep for whatever time remains after processing.</p>

<form method="post" action="#CGI.SCRIPT_NAME#">
    <label for="minMs">Minimum page duration (ms):</label>
    <input
        type="number"
        id="minMs"
        name="minMs"
        min="0"
        max="60000"
        value="#HTMLEditFormat(FORM.minMs ?: '1000')#"
        required
    >
    <br>
    <button type="submit">Run Test</button>
</form>

<cfif CGI.REQUEST_METHOD EQ "POST">

    <!--- Retrieve and sanitise input --->
    <cfset minMs = Val(FORM.minMs)>
    <cfif minMs LT 0>  <cfset minMs = 0>   </cfif>
    <cfif minMs GT 60000><cfset minMs = 60000></cfif>

    <!--- How long has processing taken so far? --->
    <cfset afterFormMs  = getTickCount() - pageStart>
    <cfset remaining    = minMs - afterFormMs>
    <cfset sleepApplied = 0>

    <!--- Sleep for the remaining time if we haven't hit the minimum yet --->
    <cfif remaining GT 0>
        <cfset sleepApplied = remaining>
        <cfset sleep(remaining)>
    </cfif>

    <!--- Final elapsed time (after sleep) --->
    <cfset totalElapsed = getTickCount() - pageStart>
    <cfset metMinimum   = (totalElapsed GTE minMs)>

    <div class="result">
        <h2>Results</h2>
        <table>
            <tr>
                <td>Minimum requested</td>
                <td>#minMs# ms</td>
            </tr>
            <tr>
                <td>Elapsed before sleep</td>
                <td>#afterFormMs# ms</td>
            </tr>
            <tr>
                <td>Time already expired</td>
                <td>#Max(0, afterFormMs)# ms
                    <cfif afterFormMs GTE minMs>
                        <span class="ok">(already met minimum &mdash; no sleep needed)</span>
                    </cfif>
                </td>
            </tr>
            <tr>
                <td>Sleep applied</td>
                <td>#sleepApplied# ms</td>
            </tr>
            <tr>
                <td>Total elapsed</td>
                <td><strong>#totalElapsed# ms</strong></td>
            </tr>
            <tr>
                <td>Minimum met?</td>
                <td>
                    <cfif metMinimum>
                        <span class="ok">Yes &check;</span>
                    <cfelse>
                        <span class="warn">No (system overhead exceeded budget)</span>
                    </cfif>
                </td>
            </tr>
        </table>
    </div>

</cfif>

</body>
</html>
