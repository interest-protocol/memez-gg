module memez_fun::memez_fun_tests;

use memez_acl::acl;
use memez_fun::{memez_fun::{Self, MemezFun}, memez_migrator_list::{Self, MemezMigratorList}};
use std::type_name;
use sui::{test_scenario::{Self as ts, Scenario}, test_utils::{assert_eq, destroy}};