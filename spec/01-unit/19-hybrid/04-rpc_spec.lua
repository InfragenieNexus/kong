-- by importing helpers, we initialize the kong PDK module
local helpers = require "spec.helpers"
local server = require("spec.helpers.rpc_mock.server")
local client = require("spec.helpers.rpc_mock.client")

describe("rpc v2", function()
  describe("full sync pagination", function()
    describe("server side", function()
      local server_mock
      lazy_setup(function()
        server_mock = server.new()
        assert(server_mock:start())

        assert(helpers.start_kong({
          database = "off",
          role = "data_plane",
          cluster_cert = "spec/fixtures/kong_spec.crt",
          cluster_cert_key = "spec/fixtures/kong_spec.key",
          cluster_rpc = "on",
          cluster_rpc_sync = "on",
          log_level = "debug",
          cluster_control_plane = "localhost:8005",
        }))
      end)
      lazy_teardown(function()
        server_mock:stop(true)
        helpers.stop_kong(nil, true)
      end)

      it("works", function()
        -- the initial sync is flaky. let's trigger a sync by creating a service
        local admin_client = helpers.admin_client()
        assert.res_status(201, admin_client:send {
          method = "POST",
          path = "/services/",
          body = {
            name = "mockbin",
            url = "http://mockbin.org",
          },
          headers = {
            ["Content-Type"] = "application/json",
          },
        })

        helpers.wait_until(function()
          return server_mock.records and next(server_mock.records)
        end,20)
      end)
    end)
    
    describe("client side", function()
      local client_mock
      lazy_setup(function()
        client_mock = assert(client.new())
        helpers.start_kong({
          role = "control_plane",
          cluster_cert = "spec/fixtures/kong_spec.crt",
          cluster_cert_key = "spec/fixtures/kong_spec.key",
          cluster_rpc = "on",
          cluster_rpc_sync = "on",
        })
        client_mock:start()        
      end)
      lazy_teardown(function()
        helpers.stop_kong(nil, true)
        client_mock:stop()
      end)

      it("works", function()
        client_mock:wait_until_connected()
        
        local res, err = client_mock:call("control_plane", "kong.sync.v2.get_delta", { default = { version = 0,},})
        assert.is_nil(err)
        assert.is_table(res and res.default and res.default.deltas)

        local res, err = client_mock:call("control_plane", "kong.sync.v2.unknown", { default = { },})
        assert.is_string(err)
      end)
    end)
  end)
end)
