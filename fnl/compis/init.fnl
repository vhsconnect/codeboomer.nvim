(global vim vim)
(local config (require :compis.config))
(local provider (require :compis.provider))

(local M {})

(set M.setup (fn [opts]
               (config.setup opts)))

(local promise vim.schedule)
(fn schedule-notify [msg level]
  (promise #(vim.notify msg level)))

(set M.ask
     (fn [question]
       (let [system-prompt "You are a helpful assistant. Answer concisely."]
         (provider.complete system-prompt question
                            (fn [result err]
                              (if err
                                  (schedule-notify (.. "compis: " err)
                                                   vim.log.levels.ERROR)
                                  (let [content (?. result :choices 1 :message
                                                    :content)]
                                    (if content
                                        (schedule-notify content
                                                         vim.log.levels.INFO)
                                        (schedule-notify "compis: no response content"
                                                         vim.log.levels.WARN)))))))))

M
