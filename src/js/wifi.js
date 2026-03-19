const result = document.getElementById("scan-results");
const button = document.getElementById("wifi-scan-btn");
const setbutton = document.getElementById("set-wifi-btn");
const setresult = document.getElementById("set-wifi-results");
const conlist = document.getElementById("wifi-conn-list");
var configuredSSIDs = [];

document.addEventListener("DOMContentLoaded", function() {
	button.addEventListener("click", wifi_scan_run);
	setbutton.addEventListener("click" , set_wifi_run);
	get_wifi_run();

	// Send a 'init' message.  This tells integration tests that we are ready to go
	cockpit.transport.wait(function() { });
});

// WiFi Scan Functions
function wifi_scan_run() {
    /* global cockpit */
	result.innerHTML = `<span class="wifi-scan-loader"></span>`;
	cockpit.spawn(["/usr/share/cockpit/wifimanager/bin/wifi-scan.py"] ,
		{ superuser: "require" } )
            .stream(wifi_scan_output)
            .catch(wifi_scan_fail);
}

function wifi_scan_fail() {
	result.innerHTML = `<span class="wifi-scan-error">WiFi scan failed</span>`;
}

function wifi_scan_output(dataStr) {
    var data = JSON.parse(dataStr);
    data = data.filter(function(item) { return configuredSSIDs.indexOf(item["ssid"]) === -1; });
    if (!data.length) {
        result.innerHTML = '<i>No new networks found</i>';
        return;
    }
    const table = document.createElement('table');
    table.classList.add("table", "table-striped", "table-hover");
    const thead = document.createElement('thead');
    const headerRow = document.createElement('tr');

    ["SSID", "SIGNAL", ""].forEach(function(label) {
        const th = document.createElement('th');
        th.setAttribute("scope", "col");
        th.textContent = label;
        headerRow.appendChild(th);
    });
    thead.appendChild(headerRow);
    table.appendChild(thead);

    const tbody = document.createElement('tbody');
    data.forEach(function(item) {
        const row = document.createElement('tr');
        const tdSsid = document.createElement('td');
        tdSsid.textContent = item["ssid"];
        row.appendChild(tdSsid);
        const tdSignal = document.createElement('td');
        tdSignal.textContent = item["signal"] + "%";
        row.appendChild(tdSignal);
        const td = document.createElement('td');
        const btn = document.createElement("button");
        btn.textContent = "Add";
        btn.classList.add("btn", "btn-sm", "btn-outline-primary");
        btn.addEventListener("click", function() { scan_add_config_run(item["ssid"]); });
        td.appendChild(btn);
        row.appendChild(td);
        tbody.appendChild(row);
    });
    table.appendChild(tbody);
    result.innerHTML = "";
    result.appendChild(table);
}


// WiFi Set Functions
function set_wifi_run() {
	let net_name = document.getElementById("wifi-ssid");
	let net_key = document.getElementById("wifi-key");

	if( net_name.value.length < 1 || net_name.value.length > 32 ){
		net_name.classList.add("is-invalid");
		setresult.innerHTML = `<span class="wifi-scan-error">SSID must be between 1 and 32 characters</span>`;
		return false;
	} else {
		net_name.classList.remove("is-invalid");
	}

	if( net_key.value.length < 8 || net_key.value.length > 64 ){
		net_key.classList.add("is-invalid");
		setresult.innerHTML = `<span class="wifi-scan-error">PSK must be between 8 and 64 characters</span>`;
		return false;
	} else {
		net_key.classList.remove("is-invalid");
	}

	cockpit.spawn(["/usr/share/cockpit/wifimanager/bin/wifi-set.sh", net_name.value, net_key.value] ,
		{ superuser: "require" } )
            .stream(set_wifi_output)
            .catch(set_wifi_fail);
}

function set_wifi_fail() {
	setresult.innerHTML = `<span class="wifi-scan-error">WiFi set failed</span>`;
}

function set_wifi_output(data) {
	setresult.innerHTML = `${data}`;
	get_wifi_run();
}

// WiFi Get Connections Functions
function get_wifi_run() {
    cockpit.spawn(["/usr/share/cockpit/wifimanager/bin/wifi-list-configured.py"] ,
        { superuser: "require" } )
            .stream(get_wifi_output)
            .catch(get_wifi_fail);
}

function get_wifi_fail() {
	conlist.innerHTML = `<span class="wifi-scan-error">WiFi list failed</span>`;
}

function get_wifi_output(dataStr) {
    const data = JSON.parse(dataStr);
    configuredSSIDs = data.map(function(item) { return item["ssid"]; });
    if (!data.length) {
        conlist.innerHTML = '<i>No configured networks</i>';
        return;
    }
    render_wifi_table(data);
}


// Delete a configured WiFi network
function del_wifi_run(connId) {
    if (!confirm("Are you sure you want to delete the network \"" + connId + "\"?")) {
        return;
    }
    cockpit.spawn(["/usr/share/cockpit/wifimanager/bin/wifi-del-configured.sh", connId],
        { superuser: "require" })
            .then(function() {
                setTimeout(function() { get_wifi_run(); }, 2000);
            })
            .catch(function() {
                conlist.innerHTML = '<span class="wifi-scan-error">Failed to delete ' + connId + '</span>';
            });
}

// Add a scanned network to saved configurations (without connecting)
function scan_add_config_run(ssid) {
    var password = prompt("Enter password for \"" + ssid + "\":");
    if (password === null) return; // cancelled

    if (password.length > 0 && (password.length < 8 || password.length > 64)) {
        result.innerHTML = '<span class="wifi-scan-error">Password must be 8-64 characters</span>';
        return;
    }

    result.innerHTML = '<span class="wifi-scan-loader"></span> Adding ' + ssid + ' to saved networks...';
    cockpit.spawn(["/usr/share/cockpit/wifimanager/bin/wifi-set.sh", ssid, password], { superuser: "require" })
        .then(function() {
            result.innerHTML = '<span class="text-success">Added ' + ssid + '.</span>';
            conlist.insertAdjacentHTML('beforeend', '<div class="mt-2"><span class="wifi-scan-loader"></span> Updating configured networks...</div>');
            setTimeout(function() { result.innerHTML = ''; get_wifi_run(); }, 2000);
        })
        .catch(function() {
            result.innerHTML = '<span class="wifi-scan-error">Failed to add ' + ssid + '</span>';
        });
}

// Connect to an already-configured network
function connect_wifi_run(connId) {
    if (!confirm("Changing WiFi networks may disconnect your current session if you are not connected via ethernet. If disconnected, you may need to reconnect to Cockpit on a new IP address. Continue?")) {
        return;
    }
    var old = document.getElementById('wifi-connect-status');
    if (old) old.remove();
    conlist.insertAdjacentHTML('beforeend', '<div id="wifi-connect-status" class="mt-2"><span class="wifi-scan-loader"></span> Connecting to ' + connId + '...</div>');
    cockpit.spawn(["nmcli", "connection", "up", connId],
        { superuser: "require" })
            .then(function() {
                var status = document.getElementById('wifi-connect-status');
                if (status) status.remove();
                setTimeout(function() { get_wifi_run(); }, 2000);
            })
            .catch(function() {
                var status = document.getElementById('wifi-connect-status');
                if (status) status.innerHTML = '<span class="wifi-scan-error">Failed to connect to ' + connId + '</span>';
            });
}

function render_wifi_table(data) {
    const table = document.createElement('table');
    table.classList.add("table", "table-striped", "table-hover");
    const thead = document.createElement('thead');
    const headerRow = document.createElement('tr');

    ["ID", "UUID", "SSID", "STATUS", "", ""].forEach(function(label) {
        const th = document.createElement('th');
        th.setAttribute("scope", "col");
        th.textContent = label;
        headerRow.appendChild(th);
    });
    thead.appendChild(headerRow);
    table.appendChild(thead);

    const tbody = document.createElement('tbody');
    data.forEach(function(item) {
        const row = document.createElement('tr');
        ["id", "uuid", "ssid"].forEach(function(col) {
            const td = document.createElement('td');
            td.textContent = item[col];
            row.appendChild(td);
        });
        const tdStatus = document.createElement('td');
        if (item["active"]) {
            tdStatus.innerHTML = '<span class="badge bg-success">Active</span>';
        }
        row.appendChild(tdStatus);
        const tdConnect = document.createElement('td');
        if (!item["active"]) {
            const btnConnect = document.createElement("button");
            btnConnect.textContent = "Connect";
            btnConnect.classList.add("btn", "btn-sm", "btn-outline-primary");
            btnConnect.addEventListener("click", function() { connect_wifi_run(item["id"]); });
            tdConnect.appendChild(btnConnect);
        }
        row.appendChild(tdConnect);
        const tdDelete = document.createElement('td');
        const btnDelete = document.createElement("button");
        btnDelete.textContent = "Delete";
        btnDelete.classList.add("btn", "btn-sm", "btn-outline-danger");
        btnDelete.addEventListener("click", function() { del_wifi_run(item["id"]); });
        tdDelete.appendChild(btnDelete);
        row.appendChild(tdDelete);
        tbody.appendChild(row);
    });
    table.appendChild(tbody);
    conlist.innerHTML = "";
    conlist.appendChild(table);
}
