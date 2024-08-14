<!--
  Copyright (C) 2022 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("settings.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-configuration')"
          :description="error.getConfiguration"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <NsInlineNotification
          kind="info"
          :title="$t('settings.external_ip')"
          :description="descriptionMessage"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-form @submit.prevent="configureModule">
            <NsTextInput
              :label="$t('settings.ddclient_fqdn')"
              placeholder="ddclient.example.org"
              v-model.trim="ddclient_host"
              class="mg-bottom"
              :invalid-message="$t(error.ddclient_host)"
              :disabled="loading.getConfiguration || loading.configureModule"
              ref="ddclient_host"
            >
              <template #tooltip>{{
                $t("settings.ddclient_fqdn_tooltip")
              }}</template>
            </NsTextInput>
            <NsTextInput
              :label="$t('settings.ddclient_protocol')"
              placeholder="dyndns2"
              v-model.trim="ddclient_protocol"
              class="mg-bottom"
              :invalid-message="$t(error.ddclient_protocol)"
              :disabled="loading.getConfiguration || loading.configureModule"
              ref="ddclient_protocol"
            >
              <template #tooltip>{{
                $t("settings.ddclient_protocol_tooltip")
              }}</template>
            </NsTextInput>
            <NsTextInput
              :label="$t('settings.provider_fqdn')"
              placeholder="providers.example.org"
              v-model.trim="ddclient_server"
              class="mg-bottom"
              :invalid-message="$t(error.ddclient_server)"
              :disabled="loading.getConfiguration || loading.configureModule"
              ref="ddclient_server"
            >
            </NsTextInput>
            <NsTextInput
              :label="$t('settings.ddclient_login')"
              placeholder="username"
              v-model.trim="ddclient_login"
              class="mg-bottom"
              :invalid-message="$t(error.ddclient_login)"
              :disabled="loading.getConfiguration || loading.configureModule"
              ref="ddclient_login"
            >
            </NsTextInput>
            <NsTextInput
              :label="$t('settings.ddclient_password')"
              placeholder="password"
              type="password"
              v-model.trim="ddclient_password"
              class="mg-bottom"
              :invalid-message="$t(error.ddclient_login)"
              :disabled="loading.getConfiguration || loading.configureModule"
              ref="ddclient_password"
            >
            </NsTextInput>
            <!-- advanced options 
            <cv-accordion ref="accordion" class="maxwidth mg-bottom">
              <cv-accordion-item :open="toggleAccordion[0]">
                <template slot="title">{{ $t("settings.advanced") }}</template>
                <template slot="content"> </template>
              </cv-accordion-item>
            </cv-accordion> -->
            <cv-row v-if="error.configureModule">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="$t('action.configure-module')"
                  :description="error.configureModule"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <NsButton
              kind="primary"
              :icon="Save20"
              :loading="loading.configureModule"
              :disabled="loading.getConfiguration || loading.configureModule"
              >{{ $t("settings.save") }}</NsButton
            >
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";

export default {
  name: "Settings",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "settings",
      },
      urlCheckInterval: null,
      ddclient_host: "",
      ddclient_server: "",
      ddclient_protocol: "",
      ddclient_login: "",
      ddclient_password: "",
      ipv4_address: "",
      ipv6_address: "",
      loading: {
        getConfiguration: false,
        configureModule: false,
      },
      error: {
        getConfiguration: "",
        configureModule: "",
        ddclient_host: "",
        ddclient_server: "",
        ddclient_protocol: "",
        ddclient_login: "",
        ddclient_password: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    descriptionMessage() {
      return this.ipv4_address && this.ipv6_address
        ? this.$t("settings.external_ip_of_the_server_both", {
            ipv4: this.ipv4_address,
            ipv6: this.ipv6_address,
          })
        : this.ipv4_address
          ? this.$t("settings.external_ip_of_the_server_ipv4", {
              ipv4: this.ipv4_address,
            })
          : this.$t("settings.external_ip_of_the_server_ipv6", {
              ipv6: this.ipv6_address,
            });
    },
  },
  created() {
    this.getConfiguration();
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  methods: {
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getConfigurationAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getConfigurationCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
        return;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      const config = taskResult.output;
      this.ddclient_host = config.ddclient_host;
      this.ddclient_server = config.ddclient_server;
      this.ddclient_protocol = config.ddclient_protocol;
      this.ddclient_login = config.ddclient_login;
      this.ddclient_password = config.ddclient_password;
      this.ipv4_address = config.ipv4_address;
      this.ipv6_address = config.ipv6_address;

      this.loading.getConfiguration = false;
      this.focusElement("host");
    },
    validateConfigureModule() {
      this.clearErrors(this);

      let isValidationOk = true;
      if (!this.ddclient_host) {
        this.error.ddclient_host = "common.required";

        if (isValidationOk) {
          this.focusElement("ddclient_host");
        }
        isValidationOk = false;
      }
      if (!this.ddclient_server) {
        this.error.ddclient_server = "common.required";

        if (isValidationOk) {
          this.focusElement("ddclient_server");
        }
        isValidationOk = false;
      }
      if (!this.ddclient_protocol) {
        this.error.ddclient_protocol = "common.required";

        if (isValidationOk) {
          this.focusElement("ddclient_protocol");
        }
        isValidationOk = false;
      }
      if (!this.ddclient_login) {
        this.error.ddclient_login = "common.required";

        if (isValidationOk) {
          this.focusElement("ddclient_login");
        }
        isValidationOk = false;
      }
      if (!this.ddclient_password) {
        this.error.ddclient_password = "common.required";

        if (isValidationOk) {
          this.focusElement("ddclient_password");
        }
        isValidationOk = false;
      }
      return isValidationOk;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusAlreadySet = false;

      for (const validationError of validationErrors) {
        const param = validationError.parameter;
        // set i18n error message
        this.error[param] = this.$t("settings." + validationError.error);

        if (!focusAlreadySet) {
          this.focusElement(param);
          focusAlreadySet = true;
        }
      }
    },
    async configureModule() {
      this.error.test_imap = false;
      this.error.test_smtp = false;
      const isValidationOk = this.validateConfigureModule();
      if (!isValidationOk) {
        return;
      }

      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            ddclient_host: this.ddclient_host,
            ddclient_server: this.ddclient_server,
            ddclient_protocol: this.ddclient_protocol,
            ddclient_login: this.ddclient_login,
            ddclient_password: this.ddclient_password,
          },
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;

      // reload configuration
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: $spacing-06;
}

.maxwidth {
  max-width: 38rem;
}
</style>
