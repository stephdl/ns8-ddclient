# ns8-ddclient

DDclient is a dynamic DNS (DDNS) update client. It automatically updates your domain's DNS records to reflect changes in your IP address, 
allowing you to access your network or services remotely even if your IP address is not static. 
This is especially useful for home users or small businesses using dynamic IP addresses provided by their ISPs.

## Install

Instantiate the module with:

    add-module ghcr.io/nethserver/ddclient:latest 1

The output of the command will return the instance name.
Output example:

    {"module_id": "ddclient1", "image_name": "ddclient", "image_url": "ghcr.io/nethserver/ddclient:latest"}

## Configure

Let's assume that the mattermost instance is named `ddclient1`.

Launch `configure-module`, by setting the following parameters:
- `ddclient_host`: a fully qualified domain name for the dynamic hostname
- `ddclient_ipv6`: enable the ipv6
- `ddclient_login`: login to the provider
- `ddclient_password`: password to the provider
- `ddclient_protocol`: protocol to the provider
- `ddclient_server`: FQDN to the provider api
- `ddclient_daemon`: time renew in second to the provider


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

The above command will:
- start and configure the ddclient instance

## Get the configuration
You can retrieve the configuration with

```
api-cli run get-configuration --agent module/ddclient1
```

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
## Testing

Test the module using the `test-module.sh` script:


    ./test-module.sh <NODE_ADDR> ghcr.io/nethserver/ddclient:latest

The tests are made using [Robot Framework](https://robotframework.org/)

## UI translation

Translated with [Weblate](https://hosted.weblate.org/projects/ns8/).

To setup the translation process:

- add [GitHub Weblate app](https://docs.weblate.org/en/latest/admin/continuous.html#github-setup) to your repository
- add your repository to [hosted.weblate.org]((https://hosted.weblate.org) or ask a NethServer developer to add it to ns8 Weblate project
