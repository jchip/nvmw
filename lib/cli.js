"use strict";

const fs = require("fs");
const NixClap = require("nix-clap");

const packageConfig = JSON.parse(fs.readFileSync(__dirname + "/../package.json").toString());

const options = {
  proxy: {
    desc: "Pass proxy settings to callouts",
    alias: "p",
    type: "string"
  },
  "verifyssl": {
    desc: "verify SSL certificate",
    alias: "ssl",
    type: "boolean",
    default: true
  }
};

const commands = {
  install: {
    desc: "install the given version of Node",
    args: "<version>",
    exec: async parsed => {
      await require("./install")(parsed.args.version,parsed.opts.proxy,parsed.opts.verifyssl);
    }
  },
  uninstall: {
    desc: "uninstall the given version of Node",
    args: "<version>",
    exec: parsed => {
      require("./uninstall")(parsed.args.version);
    }
  },
  use: {
    desc: "use the given version of Node in current shell",
    args: "<version>",
    exec: parsed => {
      require("./use")(parsed.args.version);
    }
  },
  stop: {
    desc: "undo effects of nvm in current shell",
    exec: () => {
      require("./deactivate")();
    }
  },
  link: {
    desc: "permanently link the version of Node as default",
    args: "<version>",
    exec: parsed => {
      require("./switch")(parsed.args.version);
    }
  },
  unlink: {
    desc: "permanently unlink the default version",
    exec: () => {
      require("./switch_deactivate")();
    }
  },
  ls: {
    desc: "list the installed all Nodes",
    exec: () => {
      require("./ls").local();
    }
  },
  "ls-remote": {
    desc: "list remote versions available for install",
    exec: parsed => {
      require("./ls").remote(parsed.opts.proxy,parsed.opts.verifyssl);
    }
  },
  cleanup: {
    desc: "remove stale local caches",
    exec: () => {
      require("../lib/cleanup")();
    }
  }
};

new NixClap({
  name: "nvm",
  handlers: {
    "post-help": evt => {
      evt.self.output(`Examples:

    nvm install v10.16.0
    nvm uninstall v12.4.0
    nvm use v10.16.0

`);
    }
  }
})
  .version(packageConfig.version)
  .usage("$0 <command> [options]")
  .init(options, commands)
  .parse();
