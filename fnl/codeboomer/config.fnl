(global vim vim)

(local M {})
(local directives (require :codeboomer.directives))
(local review-agents (require :codeboomer.review-agents))
(local launch-processes (require :codeboomer.launch-processes))

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
        :flush_with_directive [:n
                               "<cmd>Codeboomer FlushWithDirective<cr>"
                               "codeboomer: flush annotations with directive to pane"]
        :pane [:n
               "<cmd>Codeboomer SetPane<cr>"
               "codeboomer: pick a target pane (tmux or nvim terminal)"]
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
        :launch_reviewer [:n
                          "<cmd>Codeboomer LaunchReviewer<cr>"
                          "codeboomer: launch a review agent in a terminal buffer"]
        :launch_process [:n
                         "<cmd>Codeboomer LaunchProcess<cr>"
                         "codeboomer: launch a configured process in a terminal"]
        :pane_toggle [:n
                      "<cmd>Codeboomer TogglePane<cr>"
                      "codeboomer: collapse or bring back the pane's terminal"]
        :sidebar_toggle [:n
                         "<cmd>Codeboomer ToggleSidebar<cr>"
                         "codeboomer: collapse or bring back the comments pane"]
        :annotate [[:n :x]
                   ":Codeboomer Annotate<cr>"
                   "codeboomer: annotate selection or whole file"]})

(fn fold-by-label [defaults entries]
  ;; entries override the built-ins by label and append new labels —
  ;; shared by the directive, review agent and launch process lists
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
  (let [prompting (or M.config.prompting {})]
    (set prompting.directives
         (fold-by-label (directives.defaults) prompting.directives))
    (set prompting.review_agents
         (fold-by-label (review-agents.defaults) prompting.review_agents))
    (set prompting.launch_processes
         (fold-by-label (launch-processes.defaults) prompting.launch_processes))
    (set M.config.prompting prompting))
  (each [k [mode rhs desc] (pairs keymaps)]
    (let [lhs (?. M.config :keybindings k)]
      (when lhs
        (vim.keymap.set mode lhs rhs {: desc}))))
  M.config)

M
