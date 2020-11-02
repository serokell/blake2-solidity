// SPDX-FileCopyrightText: 2019 Alex Beregszaszi
//
// SPDX-License-Identifier: Apache-2.0

const Migrations = artifacts.require("Migrations");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
};
