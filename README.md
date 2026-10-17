# ns8-ddclient

DDclient is a dynamic DNS (DDNS) update client. It automatically updates your domain's DNS records to reflect changes in your IP address, 
allowing you to access your network or services remotely even if your IP address is not static. 
This is especially useful for home users or small businesses using dynamic IP addresses provided by their ISPs.

## Install

Instantiate the module with:

    add-module ghcr.io/stephdl/ddclient:latest 1

The output of the command will return the instance name.
Output example:

    {"module_id": "ddclient1", "image_name": "ddclient", "image_url": "ghcr.io/stephdl/ddclient:latest"}

## Configure

Let's assume that the ddclient instance is named `ddclient1`.

Launch `configure-module`, by setting the following parameters:
- `ddclient_host`: a fully qualified domain name for the dynamic hostname
- `ddclient_ipv6`: enable the ipv6
- `ddclient_protocol`: protocol to the provider, one of the keys of `imageroot/etc/protocols.json`
- `ddclient_server`: FQDN to the provider api. An empty string selects the protocol default
- `ddclient_daemon`: time renew in second to the provider
- `ddclient_login`: login to the provider, for the protocols that use it
- `ddclient_password`: password or token for the provider, for the protocols that use it
- `ddclient_apikey`, `ddclient_secretapikey`: API keys, for `porkbun`
- `ddclient_root_domain`: root domain of `ddclient_host`, for `porkbun`. Optional

The last five are optional. An empty or missing secret (`ddclient_password`,
`ddclient_apikey`, `ddclient_secretapikey`) keeps the stored value.

Example:

```
api-cli run configure-module --agent module/ddclient1 --data - <<EOF
{
    "ddclient_daemon": "300",
    "ddclient_host": "domain.dynu.net",
    "ddclient_ipv6": false,
    "ddclient_login": "username",
    "ddclient_password": "XXXXXXX",
    "ddclient_protocol": "dyndns2",
    "ddclient_server": "api.dynu.net"
}
EOF
```

Porkbun example. Create the API keys first, see
https://kb.porkbun.com/article/190-getting-started-with-the-porkbun-api,
and enable API access on the domain:

```
api-cli run configure-module --agent module/ddclient1 --data - <<EOF
{
    "ddclient_daemon": "300",
    "ddclient_host": "home.example.com",
    "ddclient_ipv6": false,
    "ddclient_apikey": "pk1_XXXXXXX",
    "ddclient_secretapikey": "sk1_XXXXXXX",
    "ddclient_root_domain": "example.com",
    "ddclient_protocol": "porkbun",
    "ddclient_server": ""
}
EOF
```

The above command will:
- start and configure the ddclient instance

## Protocols

The module runs ddclient 4.0.0. `imageroot/etc/protocols.json` lists the
protocols the module can configure, with the default server and the
variables of each one, as declared in the `%protocols` table of
`ddclient.in`. Both the UI and `bin/write-ddclient-conf` read it, so a
host entry carries only the variables its protocol uses.

Secrets are stored in `state/password.env`, passed to the container with
`--env-file`, and referenced in `ddclient.conf` as `password_env=`,
`apikey_env=`, `secretapikey_env=`. They never appear in the configuration
file, and any character in them is safe. A `#` in the login is refused:
ddclient strips it as a comment even inside quotes.

Fields used by each protocol:

| Protocol | Default server | Fields |
|---|---|---|
| `changeip` | `nic.changeip.com` | login, password |
| `dslreports1` | `www.dslreports.com` | login, password |
| `duckdns` | `www.duckdns.org` | password (the token) |
| `dyndns1`, `dyndns2` | `members.dyndns.org` | login, password |
| `easydns` | `api.cp.easydns.com` | login, password |
| `namecheap` | `dynamicdns.park-your-domain.com` | login, password |
| `porkbun` | `api.porkbun.com` | apikey, secretapikey, root-domain (optional) |
| `zoneedit1` | `dynamic.zoneedit.com` | login, password |

If a required field is empty, the host entry is not written and the reason
is logged in the module journal.

`googledomains`, `dnspark` and `nsupdate` are no longer offered. An instance
still configured with one of them keeps its settings, but the host entry is
not written: ddclient 4 would silently replace an unknown protocol with
`dyndns2` and send the credentials to `members.dyndns.org`. The UI shows a
warning until another protocol is saved.

## Get the configuration
You can retrieve the configuration with

```
api-cli run get-configuration --agent module/ddclient1
```

Secrets are never sent back: `ddclient_password`, `ddclient_apikey` and
`ddclient_secretapikey` are always empty strings. `ddclient_stored_secrets`
lists the secrets that have a stored value, for example
`["apikey", "secretapikey"]`.

## Update from 1.1.x

The update needs no action for protocols that use a login and a password:
the host entry is written again with the same values.

- `porkbun` could not work before. After the update its host entry is not
  written until the API key and the secret API key are saved.
- An instance still on `googledomains`, `dnspark` or `nsupdate` is not
  updated anymore. Choose another protocol and save.
- A password with a `#` or a space was cut by ddclient before. It is now
  passed whole.
- Restoring a backup taken with 1.1.x fails, since the restore reinstalls
  the version saved in the backup and that version sends the IPv6 setting
  with the wrong type. Take a new backup after the update.

## Uninstall

To uninstall the instance:

    remove-module --no-preserve ddclient1

## Smarthost setting discovery

Some configuration settings, like the smarthost setup, are not part of the
`configure-module` action input: they are discovered by looking at some
Redis keys.  To ensure the module is always up-to-date with the
centralized [smarthost
setup](https://nethserver.github.io/ns8-core/core/smarthost/) every time
ddclient starts, the command `bin/discover-smarthost` runs and refreshes
the `state/smarthost.env` file with fresh values from Redis.

Furthermore if smarthost setup is changed when ddclient is already
running, the event handler `events/smarthost-changed/10reload_services`
restarts the main module service.

See also the `systemd/user/ddclient.service` file.

This setting discovery is just an example to understand how the module is
expected to work: it can be rewritten or discarded completely.

## Debug

some CLI are needed to debug

- The module runs under an agent that initiate a lot of environment variables (in /home/ddclient1/.config/state), it could be nice to verify them
on the root terminal

    `runagent -m ddclient1 env`

- you can become runagent for testing scripts and initiate all environment variables
  
    `runagent -m ddclient1`

 the path become : 
```
    echo $PATH
    /home/ddclient1/.config/bin:/usr/local/agent/pyenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/
```

- if you want to debug a container or see environment inside
 `runagent -m ddclient1`

```
podman ps
```

you can see what environment variable is inside the container
```
podman exec  ddclient-app env
```

you can run a shell inside the container

```
podman exec -ti   ddclient-app sh
/ # 
```

- ddclient messages go to the journal under the instance name, like the
  rest of the module. Each update attempt logs a `SUCCESS` or `FAILED` line:

```
journalctl -t ddclient1 | grep -E "SUCCESS|FAILED"
```

- the generated configuration is `config/ddclient.conf` in the state
  directory. If the host entry is missing, the journal says why:

```
journalctl -t ddclient1 | grep -E "is required|not supported"
```

- to see what ddclient sends to the provider, run one update pass by hand
  in the container. `-force` sends an update even if the address did not
  change, and `-debug` prints the secrets, so do not share the output:

```
runagent -m ddclient1 podman exec ddclient-app sh -c 'sed /^daemon=/d /config/ddclient.conf > /tmp/t.conf && chmod 600 /tmp/t.conf && ddclient -foreground -force -verbose -debug -file /tmp/t.conf -cache /tmp/t.cache; rm -f /tmp/t.conf /tmp/t.cache'
```
## Testing

The runner lives in `ns8-github-actions`, shared by every module. Install it once:

    curl -o /tmp/run-ns8-tests https://raw.githubusercontent.com/NethServer/ns8-github-actions/v1/scripts/test-module.sh
    install -m 0755 -Z /tmp/run-ns8-tests ~/.local/bin

Then, from this directory:

    run-ns8-tests <NODE_ADDR> ghcr.io/stephdl/ddclient:latest

Add `RUN_UI_TESTS=true` to also run the cases tagged `ui`, which capture the
module pages of cluster-admin in `tests/outputs/browser/screenshot/`.

The tests are made using [Robot Framework](https://robotframework.org/)

No test calls a real provider. The cases that run ddclient set the server
to `ddns.example.invalid`, which never resolves, and check the request
ddclient builds from the generated configuration: URL, login, password and
API keys.

## UI translation

Translated with [Weblate](https://hosted.weblate.org/projects/ns8/).

To setup the translation process:

- add [GitHub Weblate app](https://docs.weblate.org/en/latest/admin/continuous.html#github-setup) to your repository
- add your repository to [hosted.weblate.org]((https://hosted.weblate.org) or ask a NethServer developer to add it to ns8 Weblate project
