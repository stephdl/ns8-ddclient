*** Settings ***
Library    SSHLibrary

*** Variables ***
${CLUSTER_USER}     admin
${CLUSTER_PASSWORD}    Nethesis,1234
${TEST_HOST}        ddclient.ns8-ci.test
${TEST_SERVER}      members.dyndns.org
${TEST_LOGIN}       ns8-ci
${TEST_PASSWORD}    Nethesis,1234
${TEST_PROTOCOL}    dyndns2
${TEST_DAEMON}      300
${PB_HOST}          home.ns8-ci.test
${PB_ROOT}          ns8-ci.test
${PB_APIKEY}        pk1_ns8ci
${PB_SECRET}        sk1_ns8#ci
# .invalid never resolves: ddclient builds its request, then fails on DNS
# before anything reaches a provider
${NO_SERVER}        ddns.example.invalid
${TRICKY_PASSWORD}    pa#ss word
${TRICKY_APIKEY}    pk1_ns8 #ci

*** Keywords ***
Login to cluster-admin
    New Page    https://${NODE_ADDR}/cluster-admin/
    Fill Text    text="Username"    ${CLUSTER_USER}
    Click    button >> text="Continue"
    Fill Text    text="Password"    ${CLUSTER_PASSWORD}
    Click    button >> text="Log in"
    Wait For Elements State    css=#main-content    visible    timeout=10s

Rendered configuration should carry
    [Arguments]    ${text}
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'cat $AGENT_STATE_DIR/config/ddclient.conf'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    ${text}

Container configuration should carry
    [Arguments]    ${text}
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec ddclient-app cat /config/ddclient.conf
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    ${text}

Run ddclient once
    [Documentation]    Run one update pass with the configuration the module
    ...                copied into the container, and return its debug log.
    ...                The address is fixed so the pass needs no IP discovery.
    [Arguments]    ${host}
    Wait Until Keyword Succeeds    60s    2s    Container configuration should carry    ${host}
    ${output} =    Execute Command
    ...    runagent -m ${module_id} podman exec ddclient-app sh -c 'sed -e "/^daemon=/d" -e "/^usev6=/d" -e "s/^usev4=.*/usev4=ipv4, ipv4=192.0.2.10/" /config/ddclient.conf > /tmp/t.conf && chmod 600 /tmp/t.conf && timeout 60 ddclient -foreground -force -debug -verbose -noquiet -file /tmp/t.conf -cache /tmp/t.cache 2>&1; rm -f /tmp/t.conf /tmp/t.cache'
    Should Not Contain    ${output}    unrecognized keyword
    Should Not Contain    ${output}    invalid value
    Should Not Contain    ${output}    not set for keyword
    RETURN    ${output}

*** Test Cases ***
Check if ddclient is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if ddclient can be configured
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"ddclient_host":"${TEST_HOST}","ddclient_server":"${TEST_SERVER}","ddclient_login":"${TEST_LOGIN}","ddclient_password":"${TEST_PASSWORD}","ddclient_protocol":"${TEST_PROTOCOL}","ddclient_daemon":"${TEST_DAEMON}","ddclient_ipv6":false}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if ddclient configuration reads back
    # No virtual host case: this module declares no traefik route, it only
    # talks to the dynamic DNS provider.
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/get-configuration --data '{}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${config} =    Evaluate    json.loads('''${output}''')    modules=json
    Should Be Equal    ${config}[ddclient_host]        ${TEST_HOST}
    Should Be Equal    ${config}[ddclient_server]      ${TEST_SERVER}
    Should Be Equal    ${config}[ddclient_login]       ${TEST_LOGIN}
    Should Be Equal    ${config}[ddclient_protocol]    ${TEST_PROTOCOL}
    Should Be Equal    ${config}[ddclient_daemon]      ${TEST_DAEMON}

Check if the generated configuration carries the settings
    # bin/write-ddclient-conf renders templates/ddclient.conf.tmpl into the
    # state directory: it is the only output of this module
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'cat $AGENT_STATE_DIR/config/ddclient.conf'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    daemon=${TEST_DAEMON}
    Should Contain    ${output}    server=${TEST_SERVER}
    Should Contain    ${output}    protocol=${TEST_PROTOCOL}
    Should Contain    ${output}    login=${TEST_LOGIN}
    Should Contain    ${output}    ${TEST_HOST}

Check if the password stays out of the environment
    # It is written to password.env, read by the rendering script, and never
    # set as a module variable
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'cat $AGENT_STATE_DIR/environment'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Not Contain    ${output}    ${TEST_PASSWORD}
    Should Contain    ${output}    DDCLIENT_LOGIN=${TEST_LOGIN}

Check if every secret key is written
    # configure-module writes all keys, even empty, so the file has the same
    # shape whatever the protocol
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'cut -d= -f1 $AGENT_STATE_DIR/password.env'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Be Equal    ${output}    DDCLIENT_APIKEY\nDDCLIENT_PASSWORD\nDDCLIENT_SECRETAPIKEY

Check if a porkbun entry is rendered
    # Run the renderer alone in a scratch directory: a configure-module call
    # would restart ddclient, which would then call the porkbun API
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'cd $(mktemp -d) && printf "DDCLIENT_APIKEY=${PB_APIKEY}\\nDDCLIENT_SECRETAPIKEY=${PB_SECRET}\\n" > password.env && DDCLIENT_PROTOCOL=porkbun DDCLIENT_SERVER= DDCLIENT_HOST=${PB_HOST} DDCLIENT_ROOT_DOMAIN=${PB_ROOT} DDCLIENT_LOGIN=${TEST_LOGIN} write-ddclient-conf && cat config/ddclient.conf && rm -rf "$PWD"'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    protocol=porkbun, \\\n
    # An empty server falls back to the protocol default
    Should Contain    ${output}    server=api.porkbun.com, \\\n
    Should Contain    ${output}    apikey_env=DDCLIENT_APIKEY, \\\n
    Should Contain    ${output}    secretapikey_env=DDCLIENT_SECRETAPIKEY, \\\n
    Should Contain    ${output}    root-domain=${PB_ROOT}, \\\n
    Should End With    ${output}    \n${PB_HOST}
    # porkbun declares no login or password, and the keys stay in the
    # container environment
    Should Not Contain    ${output}    login=
    Should Not Contain    ${output}    password
    Should Not Contain    ${output}    ${PB_APIKEY}
    Should Not Contain    ${output}    ${PB_SECRET}

Check if a protocol removed from ddclient 4 gets no entry
    # ddclient 4 would replace it with dyndns2 and send the credentials to
    # members.dyndns.org
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'cd $(mktemp -d) && DDCLIENT_PROTOCOL=googledomains DDCLIENT_HOST=${PB_HOST} write-ddclient-conf && cat config/ddclient.conf && rm -rf "$PWD"'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Not Contain    ${output}    ${PB_HOST}
    Should Not Contain    ${output}    protocol=

Check if the services are running
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} systemctl --user is-active ddclient.service ddclient-app.service
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0

Check if an incomplete configuration is refused
    # The agent exits 10 on a JSON Schema input validation failure, and this
    # action requires seven fields
    ${errors}  ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"ddclient_host":"${TEST_HOST}"}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  10
    # A missing required field is reported on the whole object, and the field
    # name goes to stderr, which Execute Command does not return here
    Should Contain    ${errors}    (root)_required

Check if a second configuration is applied
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"ddclient_host":"second.${TEST_HOST}","ddclient_server":"${TEST_SERVER}","ddclient_login":"${TEST_LOGIN}","ddclient_password":"${TEST_PASSWORD}","ddclient_protocol":"${TEST_PROTOCOL}","ddclient_daemon":"600","ddclient_ipv6":false}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    # write-ddclient-conf renders the file from ExecStartPre of ddclient-app,
    # so it lands when the restart reaches that unit, not when the task returns
    Wait Until Keyword Succeeds    30s    2s    Rendered configuration should carry    daemon=600
    Wait Until Keyword Succeeds    30s    2s    Rendered configuration should carry    second.${TEST_HOST}

Take screenshots of the module pages
    [Documentation]    Capture what cluster-admin shows, for the software center
    ...                entry. Tagged ui: the shared runner skips it unless
    ...                RUN_UI_TESTS is true, since it needs a browser.
    [Tags]    ui
    Import Library    Browser
    New Browser    chromium    headless=True
    New Context    ignoreHTTPSErrors=True    viewport={'width': 1280, 'height': 900}
    Login to cluster-admin
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}
    Wait For Elements State    iframe >>> h2 >> text="Status"    visible    timeout=10s
    # The page fills itself from several tasks: let them land
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/1._Status.png
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}?page=settings
    Wait For Elements State    iframe >>> h2 >> text="Settings"    visible    timeout=10s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/2._Settings.png
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}?page=about
    Wait For Elements State    iframe >>> h2 >> text="About"    visible    timeout=10s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/3._About.png
    Close Browser

Check if ddclient reads a dyndns2 entry
    # The password goes through password.env, podman --env-file and
    # password_env=: '#' and the space must reach the request untouched
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"ddclient_host":"dyn.${TEST_HOST}","ddclient_server":"${NO_SERVER}","ddclient_login":"${TEST_LOGIN}","ddclient_password":"${TRICKY_PASSWORD}","ddclient_protocol":"dyndns2","ddclient_daemon":"300","ddclient_ipv6":false}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${output} =    Run ddclient once    dyn.${TEST_HOST}
    Should Contain    ${output}    user="${TEST_LOGIN}:${TRICKY_PASSWORD}"
    Should Contain    ${output}    url="https://${NO_SERVER}/nic/update?hostname=dyn.${TEST_HOST}&myip=192.0.2.10"

Check if ddclient reads a porkbun entry
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"ddclient_host":"${PB_HOST}","ddclient_server":"${NO_SERVER}","ddclient_apikey":"${TRICKY_APIKEY}","ddclient_secretapikey":"${PB_SECRET}","ddclient_root_domain":"${PB_ROOT}","ddclient_protocol":"porkbun","ddclient_daemon":"300","ddclient_ipv6":false}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${output} =    Run ddclient once    ${PB_HOST}
    Should Contain    ${output}    root domain ${PB_ROOT}
    Should Contain    ${output}    url="https://${NO_SERVER}/api/json/v3/dns/retrieveByNameType/${PB_ROOT}/A/home"
    # ddclient sends a JSON body whose key order varies between runs
    Should Contain    ${output}    \\"apikey\\":\\"${TRICKY_APIKEY}\\"
    Should Contain    ${output}    \\"secretapikey\\":\\"${PB_SECRET}\\"

Check if ddclient is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
