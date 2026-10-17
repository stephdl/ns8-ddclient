#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

#
# Read etc/protocols.json and tell which variables a protocol needs. Shared by
# the actions, the update hooks and bin/write-ddclient-conf, so they agree on
# what makes a host entry complete.
#

import json
import os

import agent

DESCRIPTOR = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "etc", "protocols.json")
SECRETS_FILE = "password.env"
SECRET_KEYS = ["DDCLIENT_PASSWORD", "DDCLIENT_APIKEY", "DDCLIENT_SECRETAPIKEY"]


def load():
    with open(DESCRIPTOR) as fp:
        return json.load(fp)["protocols"]


def env_name(var):
    return "DDCLIENT_" + var.upper().replace("-", "_")


def read_secrets():
    # Missing before the first configure-module, partial in backups taken
    # before the API keys existed
    secrets = dict.fromkeys(SECRET_KEYS, "")
    if os.path.exists(SECRETS_FILE):
        secrets.update(agent.read_envfile(SECRETS_FILE))
    return secrets


def entry_values(protocol, host, environ, secrets):
    """Return the values of the protocol variables, filling the defaults
    that ddclient would otherwise get wrong."""
    values = {}
    for var in load()[protocol]["vars"]:
        source = secrets if var["secret"] else environ
        values[var["name"]] = source.get(env_name(var["name"]), "")
    # Without root-domain ddclient splits the host at the first dot, so
    # "example.com" would become the record "example" in the zone "com"
    if protocol == "porkbun" and not values["root-domain"] and host.count(".") == 1:
        values["root-domain"] = host
    return values


def entry_error(protocol, host, values):
    """Return None if the host entry can be written, otherwise a dict
    {"error": "unsupported_protocol" | "required" | "invalid", "field": name}."""
    protocols = load()
    if protocol not in protocols:
        return {"error": "unsupported_protocol", "field": protocol}
    for var in protocols[protocol]["vars"]:
        value = values.get(var["name"], "")
        if var["required"] and not value:
            return {"error": "required", "field": var["name"]}
        # ddclient strips everything after '#' as a comment, even inside
        # quotes. Secrets are safe: they are passed through the environment
        if not var["secret"] and ("#" in value or "\n" in value):
            return {"error": "invalid", "field": var["name"]}
    return None
