(global vim vim)

(local M {})

;; the agents LaunchReviewer can spawn; the review prompt is appended
;; to argv as the final argument
(local default-review-agents [{:label :claude :argv [:claude]}])

(fn M.defaults []
  "Return a fresh copy of the built-in review agents"
  (icollect [_ a (ipairs default-review-agents)]
    {:label a.label :argv (vim.list_slice a.argv)}))

(fn M.list []
  "Return the effective review agents from the config"
  (?. (require :codeboomer.config) :config :prompting :review_agents))

M
