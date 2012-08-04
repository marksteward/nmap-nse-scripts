description = [[
Attempts to bypass .htaccess authentication using HTTP verb tampering. 

For more information, see:
* CVE-2010-0738 http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2010-0738
* http://www.imperva.com/resources/glossary/http_verb_tampering.html
* https://www.owasp.org/index.php/Testing_for_HTTP_Methods_and_XST_%28OWASP-CM-008%29

This is a more general version of the original http-method-tamper script which tested for a JBoss vulnerability by default.
]]

---
-- @usage
-- nmap --script=http-method-tamper --script-args 'http-method-tamper.paths={/path1/,/path2/}' <target>
--
-- @args http-method-tamper.path Array of paths to check. Defaults 
-- to <code>{"/jmx-console/"}</code>.

author = "Paulino Calderon <calderon()websec.mx>"

license = "Same as Nmap--See http://nmap.org/book/man-legal.html"

categories = {"safe", "auth", "vuln"}

local http = require "http"
local shortport = require "shortport"
local stdnse = require "stdnse"
local table = require "table"



portrule = shortport.http

action = function(host, port)
	local paths = stdnse.get_script_args("http-method-tamper.paths")
    local method = stdnse.get_script_args(SCRIPT_NAME..".method") or stdnse.generate_random_string(5)
    local result = {}

	-- convert single string entry to table
	if ( "string" == type(paths) ) then
		paths = { paths }
	end
	
	-- Identify servers that answer 200 to invalid HTTP requests and exit as these would invalidate the tests
	local _, http_status, _ = http.identify_404(host,port)
	if ( http_status == 200 ) then
		stdnse.print_debug(1, "%s: Exiting due to ambiguous response from web server on %s:%s. All URIs return status 200.", SCRIPT_NAME, host.ip, port.number)
		return false
	end
    
	-- fallback to jmx-console
	paths = paths or {"/jmx-console/"}

    for _, path in ipairs(paths) do
        local getstatus = http.get(host, port, path).status

        -- Checks if HTTP authentication or a redirection to a login page is applied.
        if getstatus == 401 or getstatus == 302 then
            local req_status = nil
            if method == "HEAD" then
              req_status = http.head(host, port, path).status
            else
              local gen_req = http.generic_request(host, port, method, path)
              req_status = gen_req.status
            end
            if req_status == 500 and path == "/jmx-console/" then
                -- JBoss authentication bypass.
                table.insert(result, ("%s: Vulnerable to CVE-2010-0738."):format(path))
            elseif req_status == 200 then
                -- Vulnerable to authentication bypass.
				table.insert(result, ("%s: Authentication bypass possible"):format(path))
            end
        -- Checks if no authentication is required for Jmx console
        -- which is default configuration and common.
        elseif getstatus == 200 then
			table.insert(result, ("%s: Authentication was not required"):format(path))
        end
    end
    
    return stdnse.format_output(true, result)
end