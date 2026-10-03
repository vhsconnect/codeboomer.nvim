(global vim vim)

(local M {})
(local directives (require :codeboomer.directives))
(local one-offs (require :codeboomer.one-offs))

(local keymaps
       {:send_prompt [[:n :x]
                      ":Codeboomer SendPrompt<cr>"
                      "codeboomer: send prompt to pane"]
        :send_last_prompt [[:n :x]
                           ":Codeboomer SendLastPrompt<cr>"
                           "codeboomer: resend the last prompt to pane"]
        :send_selection [:x
                         ":Codeboomer SendSelection<cr>"
                         "codeboomer: send selection to pane as-is"]
        :ask_one_off [[:n :x]
                      ":Codeboomer AskOneOff<cr>"
                      "codeboomer: run one-off query, reply shown here"]
        :flush_with_directive [:n
                               "<cmd>Codeboomer FlushWithDirective<cr>"
                               "codeboomer: flush annotations with directive to pane"]
        :pane [:n "<cmd>Codeboomer SetPane<cr>" "codeboomer: pick a tmux pane"]
        :reset_session [:n
                        "<cmd>Codeboomer ResetSession<cr>"
                        "codeboomer: reset this branch's review session"]
        :review [:n
                 "<cmd>Codeboomer Review<cr>"
                 "codeboomer: pick a PR to review on this branch"]
        :post_review [:n
                      "<cmd>Codeboomer PostReview<cr>"
                      "codeboomer: push unposted annotations to the PR"]
        :pull_review [:n
                      "<cmd>Codeboomer PullReview<cr>"
                      "codeboomer: pull the PR's inline comments into the session"]
        :annotate [[:n :x]
                   ":Codeboomer Annotate<cr>"
                   "codeboomer: annotate selection or whole file"]})

(fn fold-by-label [defaults entries]
  ;; entries override the built-ins by label and append new labels —
  ;; shared by the directive and one-off command lists
  (let [effective (vim.list_slice defaults)
        index {}]
    (each [i entry (ipairs effective)]
      (tset index entry.label i))
    (each [_ entry (ipairs (or entries []))]
      (if (. index entry.label)
          (tset effective (. index entry.label) entry)
          (table.insert effective entry)))
    effective))

;; the debug flag, read per db call by the macros in macros.fnlm —
;; nil until setup() opts set `debug = true` (macro expansion happens
;; at compile time, before setup could ever run, so the read has to
;; be a runtime call, never a baked-in value)
(fn M.debug? [] (?. M :config :debug))

(fn M.setup [opts]
  (set M.config (vim.tbl_deep_extend :force (or M.config {}) (or opts {})))
  ;; Fold the built-in prompting defaults into the config: one_off_commands
  ;; and directives override the built-ins by label / append new labels.
  (let [prompting (or M.config.prompting {})]
    (set prompting.one_off_commands
         (fold-by-label (one-offs.defaults) prompting.one_off_commands))
    (set prompting.directives
         (fold-by-label (directives.defaults) prompting.directives))
    (set M.config.prompting prompting))
  (each [k [mode rhs desc] (pairs keymaps)]
    (let [lhs (?. M.config :keybindings k)]
      (when lhs
        (vim.keymap.set mode lhs rhs {: desc}))))
  M.config)

M
