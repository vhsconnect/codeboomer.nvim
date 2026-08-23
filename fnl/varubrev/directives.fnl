(global vim vim)

(local M {})

(local pushback-reasons
       ["introducing bugs"
        "impacting readability"
        "impacting preformance heavily"
        "introducing security vulenerabilities"
        "result in data loss/inconsistency"
        "contradict original instruction"])

(local default-directives
       [{:label "Review - converse"
         :text "Review my comments. Address each point and give me feedback before making any code changes."}
        {:label "Review - execute"
         :text (.. "Review my comments. Make the changes directly unless comment merits pushback. Valid Pushback reasons include "
                   (table.concat pushback-reasons ", "))}])

(fn M.defaults []
  "Return a fresh copy of the built-in directives"
  (icollect [_ d (ipairs default-directives)]
    {:label d.label :text d.text}))

(fn M.list []
  "Return the effective directives from the config"
  (?. (require :varubrev.config) :config :prompting :directives))

(fn M.get [label]
  "Get a directive's text by its label from the config"
  (accumulate [result nil _ d (ipairs (or (M.list) []))]
    (if (= d.label label)
        d.text
        result)))

M
