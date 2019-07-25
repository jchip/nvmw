"use strict";

const fs = require("fs");
const _ = require("lodash");
const colors = require("colors");
const path = require("path");
const common = require("./common");
const needle = require("needle");

module.exports = {
  sort: function(versions) {
    function sort(left, right, index) {
      if (Number(left[index]) === Number(right[index])) {
        return index === 2 ? 0 : sort(left, right, index + 1);
      }
      return Number(left[index]) > Number(right[index]) ? 1 : -1;
    }

    if (_.size(versions) <= 0 || _.isArray(versions) === false) {
      return versions;
    }

    return versions.sort(function(left, right) {
      return sort(left.substr(1).split("."), right.substr(1).split("."), 0);
    });
  },

  local: function() {
    var nvmDir = common.getNvmDir(),
      versions = [];

    if (fs.existsSync(nvmDir) && fs.lstatSync(nvmDir).isDirectory()) {
      versions = this.sort(fs.readdirSync(nvmDir));
    }

    let linkVersion;
    const link = common.getNvmLinkDir();
    if (link && fs.existsSync(link)) {
      linkVersion = fs.readlinkSync(link).match(/(v[0-9]+\.[0-9]+\.[0-9]+)/)[0];
    }

    _.each(versions, function(version) {
      if (version === path.basename(link)) {
        return;
      }
      let linked = "";
      if (linkVersion === version) {
        linked = "(linked)";
      }
      if (process.env.NVM_USE === version) {
        console.log("* %s", version.green, linked);
      } else {
        console.log(version, linked);
      }
    });
  },

  remote: async function(proxyparam,verifyssl) {
    var options = {
      proxy: proxyparam,
      rejectUnauthorized: verifyssl
    }
    try {
      const resp = await needle("get", "http://nodejs.org/dist/", options);
      const versions = this.sort(
        _.uniq(
          _.filter(resp.body.match(/v[0-9]+.[0-9]+.[0-9]+/gi), function(version) {
            return /^(v0.[0-4].[0-9]+)|(v0.5.0)$/i.test(version) === false;
          })
        )
      );
      _.each(versions, function(version) {
        console.log(version);
      });
    } catch (err) {}
  }
};
