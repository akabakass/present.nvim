---@diagnostic disable: undefined-field
local parse = require("present")._parse_slides

local eq = assert.are.same

describe("present.parse_slides", function()
  it("should parse an empty file", function()
    eq({
      slides = {
        {
          title = "",
          body = {}
        }
      }
    }, parse {})
  end)
  it("should parse an file with one slide", function()
    eq({
      slides = {
        {
          title = "#test",
          body = {
            "this is the body"
          }
        }
      }
    }, parse {
      "#test",
      "this is the body"
    })
  end)
  it("should parse an file with two slides", function()
    eq({
      slides = {
        {
          title = "#test",
          body = {
            "this is the first body"
          }
        },
        {
          title = "#test2",
          body = {
            "this is the second body"
          }
        }
      }
    }, parse {
      "#test",
      "this is the first body",
      "#test2",
      "this is the second body"
  })
  end)
end)
