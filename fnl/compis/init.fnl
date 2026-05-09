(global vim vim)
(local config (require :compis.config))
(local curl (require :plenary.curl))

(local M {})

(set M.setup (fn [opts]
               (config.setup opts)))

(local promise vim.schedule)
(fn schedule-notify [msg level]
  (promise #(vim.notify msg level)))

(set M.ping
     (fn []
       (let [url config.config.url]
         (curl.get url
                   {:callback (fn [res]
                                (if (not= res.status 200)
                                    (schedule-notify (.. "compis: request failed – HTTP "
                                                         res.status)
                                                     vim.log.levels.ERROR)
                                    (schedule-notify res.body
                                                     vim.log.levels.INFO)))}))))

M
