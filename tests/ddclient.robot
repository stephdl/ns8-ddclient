*** Settings ***
Library    SSHLibrary

*** Variables ***
${TEST_HOST}        ddclient.ns8-ci.test
${TEST_SERVER}      members.dyndns.org
${TEST_LOGIN}       ns8-ci
${TEST_PASSWORD}    Nethesis,1234
${TEST_PROTOCOL}    dyndns2

*** Test Cases ***
Check if ddclient is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if ddclient can be configured
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"ddclient_host":"${TEST_HOST}","ddclient_server":"${TEST_SERVER}","ddclient_login":"${TEST_LOGIN}","ddclient_password":"${TEST_PASSWORD}","ddclient_protocol":"${TEST_PROTOCOL}"}'
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

Check if ddclient is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
