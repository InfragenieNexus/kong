-- This software is copyright Kong Inc. and its licensors.
-- Use of the software is subject to the agreement between your organization
-- and Kong Inc. If there is no such agreement, use is governed by and
-- subject to the terms of the Kong Master Software License Agreement found
-- at https://konghq.com/enterprisesoftwarelicense/.
-- [ END OF LICENSE 0867164ffc95e54f04670b5169c09574bdbd9bba ]

local _INJECTOR = require "kong.tracing.propagation.injectors._base"
local to_hex    = require "resty.string".to_hex

local string_format = string.format

local W3C_INJECTOR = _INJECTOR:new({
  name = "w3c",
  context_validate = {
    all = { "trace_id", "span_id" },
  },
  trace_id_allowed_sizes = { 16 },
  span_id_size_bytes = 8,
})


function W3C_INJECTOR:create_headers(out_tracing_ctx)
  local trace_id  = to_hex(out_tracing_ctx.trace_id)
  local span_id   = to_hex(out_tracing_ctx.span_id)
  local sampled   = out_tracing_ctx.should_sample and "01" or "00"

  return {
    traceparent = string_format("00-%s-%s-%s", trace_id, span_id, sampled)
  }
end


function W3C_INJECTOR:get_formatted_trace_id(trace_id)
  trace_id  = to_hex(trace_id)
  return { w3c = trace_id }
end


return W3C_INJECTOR
