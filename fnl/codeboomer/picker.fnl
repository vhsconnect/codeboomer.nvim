(global vim vim)

(local M {})

;; {k} receives the item behind the picked line; ?fzf-opts is merged
;; into fzf_exec's options (preview, fzf_opts, winopts, …)
(fn M.choose [prompt items display k ?fzf-opts]
  (let [fzf (require :fzf-lua)
        by-display {}
        lines (icollect [_ item (ipairs items)]
                (let [d (display item)]
                  (tset by-display d item)
                  d))
        on-pick (fn [selected]
                  (let [item (. by-display (. selected 1))]
                    (when item (k item))))]
    (fzf.fzf_exec lines
                  (vim.tbl_extend :force (or ?fzf-opts {})
                                  {: prompt :actions {:default on-pick}}))))

M
