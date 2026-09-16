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

*** Keywords ***
Login to cluster-admin
    New Page    https://${NODE_ADDR}/cluster-admin/
    Fill Text    text="Username"    ${CLUSTER_USER}
    Click    button >> text="Continue"
    Fill Text    text="Password"    ${CLUSTER_PASSWORD}
    Click    button >> text="Log in"
    Wait For Elements State    css=#main-content    visible    timeout=10s

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
    Should Contain    ${errors}    ddclient_server

Check if a second configuration is applied
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"ddclient_host":"second.${TEST_HOST}","ddclient_server":"${TEST_SERVER}","ddclient_login":"${TEST_LOGIN}","ddclient_password":"${TEST_PASSWORD}","ddclient_protocol":"${TEST_PROTOCOL}","ddclient_daemon":"600","ddclient_ipv6":false}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'cat $AGENT_STATE_DIR/config/ddclient.conf'
    ...    return_rc=True
    Should Contain    ${output}    daemon=600
    Should Contain    ${output}    second.${TEST_HOST}

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

Check if ddclient is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
