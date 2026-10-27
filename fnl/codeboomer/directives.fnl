(global vim vim)

(local M {})

(local pushback-reasons
       ["introducing bugs"
        "impacting readability"
        "impacting preformance heavily"
        "introducing security vulenerabilities"
        "result in data loss/inconsistency"
        "contradict original instruction"])

(local pushback-clause
       (.. "unless a comment merits pushback. Valid pushback reasons include "
           (table.concat pushback-reasons ", ")))

(local default-directives
       [{:label "Review - converse only"
         :text "Review my comments. Address each point and give me feedback. Do not make any code changes."}
        {:label "Review - converse + change"
         :text (.. "Review my comments. Address each point in its thread, then make the changes "
                   pushback-clause)}
        {:label "Review - change"
         :text (.. "Make the changes my comments ask for directly, without discussing them first, "
                   pushback-clause)}])

(fn M.defaults []
  "Return a fresh copy of the built-in directives"
  (icollect [_ d (ipairs default-directives)]
    {:label d.label :text d.text}))

(fn M.list []
  "Return the effective directives from the config"
  (?. (require :codeboomer.config) :config :prompting :directives))

(fn M.get [label]
  "Get a directive's text by its label from the config"
  (accumulate [result nil _ d (ipairs (or (M.list) []))]
    (if (= d.label label)
        d.text
        result)))

M
