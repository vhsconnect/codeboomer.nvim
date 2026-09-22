(global vim vim)

(local M {})
(local directives (require :codeboomer.directives))
(local one-offs (require :codeboomer.one-offs))

(local keymaps {:send_prompt [[:n :x]
                              ":Codeboomer SendPrompt<cr>"
                              "codeboomer: send prompt to pane"]
                :send_selection [:x
                                 ":Codeboomer SendSelection<cr>"
                                 "codeboomer: send selection to pane as-is"]
                :ask_one_off [[:n :x]
                              ":Codeboomer AskOneOff<cr>"
                              "codeboomer: run one-off query, reply shown here"]
                :flush_with_directive [:n
                                       "<cmd>Codeboomer FlushWithDirective<cr>"
                                       "codeboomer: flush annotations with directive to pane"]
                :pane [:n
                       "<cmd>Codeboomer SetPane<cr>"
                       "codeboomer: pick a tmux pane"]
                :session [:n
                          "<cmd>Codeboomer Sessions<cr>"
                          "codeboomer: manage review sessions (d deletes)"]
                :review [:n
                         "<cmd>Codeboomer Review<cr>"
                         "codeboomer: review a pull request in a read-only worktree"]
                :review_worktree [:n
                                  "<cmd>Codeboomer ReviewWorktree<cr>"
                                  "codeboomer: review the uncommitted working tree as a snapshot"]
                :review_side [:n
                              "<cmd>Codeboomer ReviewSide<cr>"
                              "codeboomer: toggle the review between new and old code"]
                :walk_forward [:n
                               "<cmd>Codeboomer WalkForward<cr>"
                               "codeboomer: walk the review forward one commit"]
                :walk_back [:n
                            "<cmd>Codeboomer WalkBack<cr>"
                            "codeboomer: walk the review back one commit"]
                :post_review [:n
                              "<cmd>Codeboomer PostReview<cr>"
                              "codeboomer: push unposted annotations to the PR"]
                :pull_review [:n
                              "<cmd>Codeboomer PullReview<cr>"
                              "codeboomer: pull the PR's inline comments into the session"]
                :annotate [:x
                           ":Codeboomer Annotate<cr>"
                           "codeboomer: annotate some text"]})

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
