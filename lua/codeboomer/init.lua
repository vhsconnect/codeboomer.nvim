-- [nfnl] fnl/codeboomer/init.fnl
vim = vim
local config = require("codeboomer.config")
local input = require("codeboomer.input")
local directives = require("codeboomer.directives")
local review = require("codeboomer.review")
local agent = require("codeboomer.agent")
local one_offs = require("codeboomer.one-offs")
local state = {pane = nil, ["session-id"] = nil}
local M = {}
local function _1_(opts)
  return config.setup(opts)
end
M.setup = _1_
local function schedule_notify(msg, level)
  local function _2_()
    return vim.notify(msg, level)
  end
  return vim.schedule(_2_)
end
local function shell(command)
  local handle = io.popen(command)
  local output = handle:read("*a")
  handle:close()
  return output
end
local panes_command = "tmux list-panes -a -F '#{session_name}|#{session_id}|#{window_index}|#{pane_index}|#{pane_id}|#{pane_current_command}|#{pane_mode}|#{pane_active}|#{window_active}|#{pane_current_path}'"
local last_lines_command = "tmux list-panes -a -F '#{pane_id}' | while read -r p; do printf '%s\\t' \"$p\"; tmux capture-pane -p -t \"$p\" -S -5 -E -1 2>/dev/null | sed -e '/^[[:space:]]*$/d' | tail -n 1; echo; done"
local function one_off_result(stdout)
  local ok, parsed = pcall(vim.json.decode, stdout)
  if (ok and (type(parsed) == "table") and parsed.result) then
    return parsed.result
  else
    return stdout
  end
end
local function run_one_off(cmd, prompt)
  local argv = vim.list_slice((cmd.argv or {}))
  local timeout = (cmd.timeout or 60000)
  local function _4_(obj)
    local function _5_()
      if (obj.code == 0) then
        return vim.notify(one_off_result((obj.stdout or "")), vim.log.levels.INFO)
      else
        return vim.notify(("codeboomer: one-off failed (exit " .. obj.code .. ")\n" .. (obj.stderr or "")), vim.log.levels.ERROR)
      end
    end
    return vim.schedule(_5_)
  end
  return vim.system(vim.list_extend(argv, {prompt}), {text = true, timeout = timeout}, _4_)
end
local function parse_panes(x)
  local pattern = "([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)"
  local result = string.gmatch(x, pattern)
  local tbl_26_ = {}
  local i_27_ = 0
  for session_name, session_id, window_index, pane_index, pane_id, pane_current_command, pane_mode, pane_active, window_active, pane_current_path in result do
    local val_28_ = {["session-name"] = session_name, ["session-id"] = session_id, ["window-index"] = window_index, ["pane-index"] = pane_index, ["pane-id"] = pane_id, ["pane-current-command"] = pane_current_command, ["pane-mode"] = pane_mode, ["pane-active"] = pane_active, ["window-active"] = window_active, ["pane-current-path"] = pane_current_path}
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
local function parse_last_lines(x)
  local result = {}
  for line in string.gmatch(x, "[^\n]+") do
    local sep = string.find(line, "\t", 1, true)
    if sep then
      result[string.sub(line, 1, (sep - 1))] = vim.trim(string.sub(line, (sep + 1)))
    else
    end
  end
  return result
end
local function shorten_path(path)
  local home = os.getenv("HOME")
  if (home and (1 == string.find(path, home, 1, true))) then
    return ("~" .. string.sub(path, (1 + #home)))
  else
    return path
  end
end
local function paste_text(pane_id, text)
  local handle = io.popen(("tmux load-buffer -b codeboomer-paste - && " .. "tmux paste-buffer -p -r -d -b codeboomer-paste -t " .. pane_id), "w")
  handle:write(text)
  return handle:close()
end
local function press_key_command(pane_id, key)
  return string.format("tmux send-keys -t %s %s", pane_id, key)
end
local function cancel_mode_command(pane_id)
  return string.format("tmux send-keys -t %s -X cancel", pane_id)
end
local function send_keys_to_selected_pane(text)
  local pane_id = state.pane["pane-id"]
  if ("" ~= state.pane["pane-mode"]) then
    shell(cancel_mode_command(pane_id))
  else
  end
  paste_text(pane_id, text)
  return shell(press_key_command(pane_id, "Enter"))
end
local last_line_max_length = 80
local function pane_display(p, last_line)
  local location = string.format("%s:%s.%s", p["session-name"], p["window-index"], p["pane-index"])
  local short_line
  if (#last_line > last_line_max_length) then
    short_line = (string.sub(last_line, 1, last_line_max_length) .. "\226\128\166")
  else
    short_line = last_line
  end
  local mode
  if (p["pane-mode"] ~= "") then
    mode = ("[" .. p["pane-mode"] .. "] ")
  else
    mode = ""
  end
  return string.format("%-6s %-11s %-18s %-30s %s%s", p["pane-id"], p["pane-current-command"], location, shorten_path(p["pane-current-path"]), mode, short_line)
end
local pane_preview_command = "tmux capture-pane -p -t {1} -S -40"
local function choose_pane(panes, _3fthen)
  local fzf = require("fzf-lua")
  local last_lines = parse_last_lines(shell(last_lines_command))
  local by_display = {}
  local lines
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, p in ipairs(panes) do
      local val_28_
      do
        local display = pane_display(p, last_lines[p["pane-id"]])
        by_display[display] = p
        val_28_ = display
      end
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    lines = tbl_26_
  end
  local function _14_(selected)
    local pane = by_display[selected[1]]
    state.pane = pane
    schedule_notify(string.format("codeboomer: pane %s (%s:%s.%s) selected", pane["pane-id"], pane["session-name"], pane["window-index"], pane["pane-index"]), vim.log.levels.INFO)
    if _3fthen then
      return _3fthen()
    else
      return nil
    end
  end
  return fzf.fzf_exec(lines, {prompt = "Pick a Pane> ", preview = pane_preview_command, fzf_opts = {["--with-nth"] = "2.."}, winopts = {preview = {layout = "vertical", vertical = "down:45%:follow", wrap = false}}, actions = {default = _14_}})
end
local one_off_argv_max_length = 80
local function one_off_display(c)
  local argv = table.concat(c.argv, " ")
  local short_argv
  if (#argv > one_off_argv_max_length) then
    short_argv = (string.sub(argv, 1, one_off_argv_max_length) .. "\226\128\166")
  else
    short_argv = argv
  end
  local timeout
  if c.timeout then
    timeout = string.format(" (%ds)", math.floor((c.timeout / 1000)))
  else
    timeout = ""
  end
  return string.format("%-22s %s%s", c.label, short_argv, timeout)
end
local function choose_one_off(commands, _3fthen)
  local fzf = require("fzf-lua")
  local by_display = {}
  local lines
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, c in ipairs(commands) do
      local val_28_
      do
        local display = one_off_display(c)
        by_display[display] = c
        val_28_ = display
      end
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    lines = tbl_26_
  end
  local function _19_(selected)
    local cmd = by_display[selected[1]]
    if _3fthen then
      return _3fthen(cmd)
    else
      return nil
    end
  end
  return fzf.fzf_exec(lines, {prompt = "Pick a One-off> ", actions = {default = _19_}})
end
M.RunOneOff = run_one_off
local function concat_list(lines)
  return table.concat(lines, "\n")
end
local function concat_list_with_format(lines, beginning, sep, _end)
  return (beginning .. "\n" .. table.concat(lines, (sep .. "\n")) .. "\n" .. _end .. "\n")
end
local function get_visual_lines(opts)
  local _22_
  do
    local t_21_ = opts
    if (nil ~= t_21_) then
      t_21_ = t_21_.range
    else
    end
    _22_ = t_21_
  end
  if (_22_ == 2) then
    local path = vim.api.nvim_buf_get_name(0)
    local ok, region_lines = pcall(vim.fn.getregion, vim.fn.getpos("'<"), vim.fn.getpos("'>"), {type = vim.fn.visualmode()})
    local lines
    if ok then
      lines = concat_list(region_lines)
    else
      lines = concat_list(vim.api.nvim_buf_get_lines(0, (opts.line1 - 1), opts.line2, false))
    end
    return {lines = lines, line1 = opts.line1, line2 = opts.line2, file = path}
  else
    return nil
  end
end
local function compose_message(context, text)
  if context then
    return ("regarding " .. context.file .. " lines " .. context.line1 .. " to " .. context.line2 .. "\n" .. context.lines .. "\n" .. text .. "\n")
  else
    local file = vim.api.nvim_buf_get_name(0)
    return ("regarding " .. file .. "\n" .. text .. "\n")
  end
end
local function annotation_message(t, c)
  return string.format("regarding %s lines %s to %s (thread %s)\n%s\n%s", (t.file_path or "?"), (t.line_start or "?"), (t.line_end or "?"), (t.id or "?"), (t.code_snapshot or ""), (c.body or ""))
end
local function _27_()
  return choose_pane(parse_panes(shell(panes_command)))
end
M.SetPane = _27_
local function _28_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    local function _29_(lines)
      local text = concat_list(lines)
      if (text ~= "") then
        return send_keys_to_selected_pane(compose_message(context, text))
      else
        return nil
      end
    end
    return input.open({title = " SendPrompt> ", ["on-submit"] = _29_})
  else
    local function _31_()
      local context = get_visual_lines(opts)
      local function _32_(lines)
        local text = concat_list(lines)
        if (text ~= "") then
          return send_keys_to_selected_pane(compose_message(context, text))
        else
          return nil
        end
      end
      return input.open({title = " SendPrompt> ", ["on-submit"] = _32_})
    end
    return choose_pane(parse_panes(shell(panes_command)), _31_)
  end
end
M.SendPrompt = _28_
local function _35_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    if context then
      return send_keys_to_selected_pane(context.lines)
    else
      return nil
    end
  else
    local function _37_()
      local context = get_visual_lines(opts)
      if context then
        return send_keys_to_selected_pane(context.lines)
      else
        return nil
      end
    end
    return choose_pane(parse_panes(shell(panes_command)), _37_)
  end
end
M.SendSelection = _35_
local function _40_(opts)
  local context = get_visual_lines(opts)
  local commands = (one_offs.list() or {})
  local ask
  local function _41_(cmd)
    local function _42_(lines)
      local text = concat_list(lines)
      if (text ~= "") then
        return run_one_off(cmd, compose_message(context, text))
      else
        return nil
      end
    end
    return input.open({title = string.format(" AskOneOff: %s (Enter to send)> ", cmd.label), ["submit-on-enter"] = true, ["on-submit"] = _42_})
  end
  ask = _41_
  if (0 == #commands) then
    return schedule_notify("codeboomer: prompting.one_off_commands not set \226\128\148 call setup() first", vim.log.levels.ERROR)
  else
    if (1 == #commands) then
      return ask(commands[1])
    else
      return choose_one_off(commands, ask)
    end
  end
end
M.AskOneOff = _40_
local function _46_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    local function _47_(lines)
      local text = concat_list(lines)
      if (text == "") then
        return schedule_notify("codeboomer: empty annotation ignored", vim.log.levels.WARN)
      else
        if state["session-id"] then
          review["user-comment"](state["session-id"], context.file, context.line1, context.line2, context.lines, text)
          return vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerAnnotated"})
        else
          local sessions_2_auto = (review["get-sessions"]() or {})
          local case_48_ = #sessions_2_auto
          if (case_48_ == 0) then
            state["session-id"] = review["create-session"]()
            review["user-comment"](state["session-id"], context.file, context.line1, context.line2, context.lines, text)
            return vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerAnnotated"})
          elseif (case_48_ == 1) then
            local _50_
            do
              local t_49_ = sessions_2_auto
              if (nil ~= t_49_) then
                t_49_ = t_49_[1]
              else
              end
              if (nil ~= t_49_) then
                t_49_ = t_49_.id
              else
              end
              _50_ = t_49_
            end
            state["session-id"] = _50_
            review["user-comment"](state["session-id"], context.file, context.line1, context.line2, context.lines, text)
            return vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerAnnotated"})
          else
            local __3_auto = case_48_
            return error("Multiple session not implemented")
          end
        end
      end
    end
    return input.open({title = " Annotate> ", ["on-submit"] = _47_})
  else
    local function _56_()
      local context = get_visual_lines(opts)
      local function _57_(lines)
        local text = concat_list(lines)
        if (text == "") then
          return schedule_notify("codeboomer: empty annotation ignored", vim.log.levels.WARN)
        else
          if state["session-id"] then
            review["user-comment"](state["session-id"], context.file, context.line1, context.line2, context.lines, text)
            return vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerAnnotated"})
          else
            local sessions_2_auto = (review["get-sessions"]() or {})
            local case_58_ = #sessions_2_auto
            if (case_58_ == 0) then
              state["session-id"] = review["create-session"]()
              review["user-comment"](state["session-id"], context.file, context.line1, context.line2, context.lines, text)
              return vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerAnnotated"})
            elseif (case_58_ == 1) then
              local _60_
              do
                local t_59_ = sessions_2_auto
                if (nil ~= t_59_) then
                  t_59_ = t_59_[1]
                else
                end
                if (nil ~= t_59_) then
                  t_59_ = t_59_.id
                else
                end
                _60_ = t_59_
              end
              state["session-id"] = _60_
              review["user-comment"](state["session-id"], context.file, context.line1, context.line2, context.lines, text)
              return vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerAnnotated"})
            else
              local __3_auto = case_58_
              return error("Multiple session not implemented")
            end
          end
        end
      end
      return input.open({title = " Annotate> ", ["on-submit"] = _57_})
    end
    return choose_pane(parse_panes(shell(panes_command)), _56_)
  end
end
M.Annotate = _46_
local function _67_()
  if state.pane then
    local fzf = require("fzf-lua")
    local all_directives = directives.list()
    local lines
    do
      local tbl_26_ = {}
      local i_27_ = 0
      for _, d in ipairs(all_directives) do
        local val_28_ = d.label
        if (nil ~= val_28_) then
          i_27_ = (i_27_ + 1)
          tbl_26_[i_27_] = val_28_
        else
        end
      end
      lines = tbl_26_
    end
    local function _69_(selected)
      local selected_label = selected[1]
      local directive_text = directives.get(selected_label)
      if state["session-id"] then
        local pending = review["pending-annotations"](state["session-id"], "sent")
        if (0 == #pending) then
          return schedule_notify("codeboomer: nothing to flush \226\128\148 no unsent annotations", vim.log.levels.WARN)
        else
          local messages
          do
            local tbl_26_ = {}
            local i_27_ = 0
            for _, a in ipairs(pending) do
              local val_28_ = annotation_message(a.thread, a.comment)
              if (nil ~= val_28_) then
                i_27_ = (i_27_ + 1)
                tbl_26_[i_27_] = val_28_
              else
              end
            end
            messages = tbl_26_
          end
          local annotations = concat_list_with_format(messages, "==Section Start==", "====", "==Section End==")
          send_keys_to_selected_pane((annotations .. agent["reply-instructions"]() .. directive_text .. "\n"))
          local function _71_()
            local tbl_26_ = {}
            local i_27_ = 0
            for _, a in ipairs(pending) do
              local val_28_ = a.comment.id
              if (nil ~= val_28_) then
                i_27_ = (i_27_ + 1)
                tbl_26_[i_27_] = val_28_
              else
              end
            end
            return tbl_26_
          end
          return review["mark-annotations"]("sent", _71_())
        end
      else
        local sessions_2_auto = (review["get-sessions"]() or {})
        local case_74_ = #sessions_2_auto
        if (case_74_ == 0) then
          state["session-id"] = review["create-session"]()
          local pending = review["pending-annotations"](state["session-id"], "sent")
          if (0 == #pending) then
            return schedule_notify("codeboomer: nothing to flush \226\128\148 no unsent annotations", vim.log.levels.WARN)
          else
            local messages
            do
              local tbl_26_ = {}
              local i_27_ = 0
              for _, a in ipairs(pending) do
                local val_28_ = annotation_message(a.thread, a.comment)
                if (nil ~= val_28_) then
                  i_27_ = (i_27_ + 1)
                  tbl_26_[i_27_] = val_28_
                else
                end
              end
              messages = tbl_26_
            end
            local annotations = concat_list_with_format(messages, "==Section Start==", "====", "==Section End==")
            send_keys_to_selected_pane((annotations .. agent["reply-instructions"]() .. directive_text .. "\n"))
            local function _76_()
              local tbl_26_ = {}
              local i_27_ = 0
              for _, a in ipairs(pending) do
                local val_28_ = a.comment.id
                if (nil ~= val_28_) then
                  i_27_ = (i_27_ + 1)
                  tbl_26_[i_27_] = val_28_
                else
                end
              end
              return tbl_26_
            end
            return review["mark-annotations"]("sent", _76_())
          end
        elseif (case_74_ == 1) then
          local _80_
          do
            local t_79_ = sessions_2_auto
            if (nil ~= t_79_) then
              t_79_ = t_79_[1]
            else
            end
            if (nil ~= t_79_) then
              t_79_ = t_79_.id
            else
            end
            _80_ = t_79_
          end
          state["session-id"] = _80_
          local pending = review["pending-annotations"](state["session-id"], "sent")
          if (0 == #pending) then
            return schedule_notify("codeboomer: nothing to flush \226\128\148 no unsent annotations", vim.log.levels.WARN)
          else
            local messages
            do
              local tbl_26_ = {}
              local i_27_ = 0
              for _, a in ipairs(pending) do
                local val_28_ = annotation_message(a.thread, a.comment)
                if (nil ~= val_28_) then
                  i_27_ = (i_27_ + 1)
                  tbl_26_[i_27_] = val_28_
                else
                end
              end
              messages = tbl_26_
            end
            local annotations = concat_list_with_format(messages, "==Section Start==", "====", "==Section End==")
            send_keys_to_selected_pane((annotations .. agent["reply-instructions"]() .. directive_text .. "\n"))
            local function _84_()
              local tbl_26_ = {}
              local i_27_ = 0
              for _, a in ipairs(pending) do
                local val_28_ = a.comment.id
                if (nil ~= val_28_) then
                  i_27_ = (i_27_ + 1)
                  tbl_26_[i_27_] = val_28_
                else
                end
              end
              return tbl_26_
            end
            return review["mark-annotations"]("sent", _84_())
          end
        else
          local __3_auto = case_74_
          return error("Multiple session not implemented")
        end
      end
    end
    return fzf.fzf_exec(lines, {prompt = "Pick a Directive> ", actions = {default = _69_}})
  else
    local function _89_()
      local fzf = require("fzf-lua")
      local all_directives = directives.list()
      local lines
      do
        local tbl_26_ = {}
        local i_27_ = 0
        for _, d in ipairs(all_directives) do
          local val_28_ = d.label
          if (nil ~= val_28_) then
            i_27_ = (i_27_ + 1)
            tbl_26_[i_27_] = val_28_
          else
          end
        end
        lines = tbl_26_
      end
      local function _91_(selected)
        local selected_label = selected[1]
        local directive_text = directives.get(selected_label)
        if state["session-id"] then
          local pending = review["pending-annotations"](state["session-id"], "sent")
          if (0 == #pending) then
            return schedule_notify("codeboomer: nothing to flush \226\128\148 no unsent annotations", vim.log.levels.WARN)
          else
            local messages
            do
              local tbl_26_ = {}
              local i_27_ = 0
              for _, a in ipairs(pending) do
                local val_28_ = annotation_message(a.thread, a.comment)
                if (nil ~= val_28_) then
                  i_27_ = (i_27_ + 1)
                  tbl_26_[i_27_] = val_28_
                else
                end
              end
              messages = tbl_26_
            end
            local annotations = concat_list_with_format(messages, "==Section Start==", "====", "==Section End==")
            send_keys_to_selected_pane((annotations .. agent["reply-instructions"]() .. directive_text .. "\n"))
            local function _93_()
              local tbl_26_ = {}
              local i_27_ = 0
              for _, a in ipairs(pending) do
                local val_28_ = a.comment.id
                if (nil ~= val_28_) then
                  i_27_ = (i_27_ + 1)
                  tbl_26_[i_27_] = val_28_
                else
                end
              end
              return tbl_26_
            end
            return review["mark-annotations"]("sent", _93_())
          end
        else
          local sessions_2_auto = (review["get-sessions"]() or {})
          local case_96_ = #sessions_2_auto
          if (case_96_ == 0) then
            state["session-id"] = review["create-session"]()
            local pending = review["pending-annotations"](state["session-id"], "sent")
            if (0 == #pending) then
              return schedule_notify("codeboomer: nothing to flush \226\128\148 no unsent annotations", vim.log.levels.WARN)
            else
              local messages
              do
                local tbl_26_ = {}
                local i_27_ = 0
                for _, a in ipairs(pending) do
                  local val_28_ = annotation_message(a.thread, a.comment)
                  if (nil ~= val_28_) then
                    i_27_ = (i_27_ + 1)
                    tbl_26_[i_27_] = val_28_
                  else
                  end
                end
                messages = tbl_26_
              end
              local annotations = concat_list_with_format(messages, "==Section Start==", "====", "==Section End==")
              send_keys_to_selected_pane((annotations .. agent["reply-instructions"]() .. directive_text .. "\n"))
              local function _98_()
                local tbl_26_ = {}
                local i_27_ = 0
                for _, a in ipairs(pending) do
                  local val_28_ = a.comment.id
                  if (nil ~= val_28_) then
                    i_27_ = (i_27_ + 1)
                    tbl_26_[i_27_] = val_28_
                  else
                  end
                end
                return tbl_26_
              end
              return review["mark-annotations"]("sent", _98_())
            end
          elseif (case_96_ == 1) then
            local _102_
            do
              local t_101_ = sessions_2_auto
              if (nil ~= t_101_) then
                t_101_ = t_101_[1]
              else
              end
              if (nil ~= t_101_) then
                t_101_ = t_101_.id
              else
              end
              _102_ = t_101_
            end
            state["session-id"] = _102_
            local pending = review["pending-annotations"](state["session-id"], "sent")
            if (0 == #pending) then
              return schedule_notify("codeboomer: nothing to flush \226\128\148 no unsent annotations", vim.log.levels.WARN)
            else
              local messages
              do
                local tbl_26_ = {}
                local i_27_ = 0
                for _, a in ipairs(pending) do
                  local val_28_ = annotation_message(a.thread, a.comment)
                  if (nil ~= val_28_) then
                    i_27_ = (i_27_ + 1)
                    tbl_26_[i_27_] = val_28_
                  else
                  end
                end
                messages = tbl_26_
              end
              local annotations = concat_list_with_format(messages, "==Section Start==", "====", "==Section End==")
              send_keys_to_selected_pane((annotations .. agent["reply-instructions"]() .. directive_text .. "\n"))
              local function _106_()
                local tbl_26_ = {}
                local i_27_ = 0
                for _, a in ipairs(pending) do
                  local val_28_ = a.comment.id
                  if (nil ~= val_28_) then
                    i_27_ = (i_27_ + 1)
                    tbl_26_[i_27_] = val_28_
                  else
                  end
                end
                return tbl_26_
              end
              return review["mark-annotations"]("sent", _106_())
            end
          else
            local __3_auto = case_96_
            return error("Multiple session not implemented")
          end
        end
      end
      return fzf.fzf_exec(lines, {prompt = "Pick a Directive> ", actions = {default = _91_}})
    end
    return choose_pane(parse_panes(shell(panes_command)), _89_)
  end
end
M.FlushWithDirective = _67_
return M
