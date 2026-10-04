(local helpers (require :cb_helpers))

(local {: clear : eq : api} helpers)
(local exec-lua helpers.exec_lua)

(helpers.env)

(fn open-input [opts]
  (exec-lua (fn [opts]
              (set _G.submissions [])
              ((. (require :codeboomer.input) :open) (vim.tbl_extend :force
                                                                     opts
                                                                     {:on_submit #(table.insert _G.submissions
                                                                                                $1)})))
            opts))

(fn set-lines [win lines]
  (exec-lua (fn [win lines]
              (vim.api.nvim_buf_set_lines (vim.api.nvim_win_get_buf win) 0 -1
                                          false lines)) win lines))

(fn press [win keys]
  (exec-lua (fn [win keys]
              (vim.api.nvim_win_call win
                                     #(vim.api.nvim_feedkeys (vim.keycode keys)
                                                             :x false)))
            win keys))

(fn submissions []
  (exec-lua "return _G.submissions"))

(describe :input
          (fn []
            (before_each (fn []
                           (clear)
                           (helpers.setup-codeboomer)))
            (it "submits every line and closes on <CR> with submit_on_enter"
                (fn []
                  (let [win (open-input {:title " test " :submit_on_enter true})]
                    (set-lines win ["echo hello" "echo world"])
                    (press win :<CR>)
                    (eq [["echo hello" "echo world"]] (submissions))
                    (eq false (api.nvim_win_is_valid win)))))
            (it "does not submit on <CR> by default"
                (fn []
                  (let [win (open-input {})]
                    (set-lines win ["first line"])
                    (press win :<CR>)
                    (eq [] (submissions))
                    (eq true (api.nvim_win_is_valid win)))))
            (it "submits when the window is closed directly"
                (fn []
                  (let [win (open-input {})]
                    (set-lines win ["typed stuff"])
                    (api.nvim_win_close win true)
                    (eq [["typed stuff"]] (submissions)))))
            (it "seeds the buffer from prefill"
                (fn []
                  (let [win (open-input {:prefill "one\ntwo"})]
                    (api.nvim_win_close win true)
                    (eq [[:one :two]] (submissions)))))
            (it "leaves no windows behind"
                (fn []
                  (let [wins-before (length (api.nvim_list_wins))
                        win (open-input {:submit_on_enter true})]
                    (press win :<CR>)
                    (eq wins-before (length (api.nvim_list_wins))))))))
