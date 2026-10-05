(global vim vim)

(local review (require :codeboomer.review))
(local input (require :codeboomer.input))
(local git (require :codeboomer.git))
(local github (require :codeboomer.github))

(local M {})

(local augroup-name :codeboomer-review-pane)
(local pane-buf-name "codeboomer://review-comments")
(local extmark-ns (vim.api.nvim_create_namespace :codeboomer-review-pane))
(local flash-ns (vim.api.nvim_create_namespace :codeboomer-review-flash))
(local flash-ms 2000)
(local pane-width 40)
(local pane-keys-footer [(.. "── keys " (string.rep "─" (- pane-width 8)))
                         "r reply · a agent · d delete"
                         "p promote · e edit · f refresh"
                         "q resolve · n/N thread"])

(local rest-ms 100)
(local db-refresh-ms 5000)

(var pane-win nil)
(var threads-by-path {})
(var all-threads [])
(var timer-id nil)
(var db-refresh-timer nil)
(var pane-source-win nil)
(var pane-path nil)
(var current-thread nil)
(var pane-header-rows [])

(fn thread-hl [index]
  (let [groups [:Title :Special :String :Function]]
    (. groups (+ 1 (% (- index 1) (length groups))))))

(fn normal-buf [bufnr]
  (= "" (or (?. vim.bo bufnr :buftype) "")))

;; a window the pane may open for or follow: a split (not a float —
;; plugin popups and previews) on a real file inside a work tree.
;; Terminals, plugin scratch buffers and unnamed buffers never qualify
(fn source-win? [win]
  (let [buf (vim.api.nvim_win_get_buf win)
        name (vim.api.nvim_buf_get_name buf)]
    (and (= "" (or (?. (vim.api.nvim_win_get_config win) :relative) ""))
         (normal-buf buf) (not= "" name) (= 1 (vim.fn.filereadable name))
         (not= nil (git.work-root name)))))

(var rel-path-cache {})
(fn buf-rel-path [bufnr]
  (or (. rel-path-cache bufnr) (let [p (git.rel-path (vim.api.nvim_buf_get_name bufnr))]
                                 (tset rel-path-cache bufnr p)
                                 p)))

(fn source-buf-name []
  (let [cur (vim.api.nvim_get_current_win)
        ;; the pane itself and any floating window over it (the input,
        ;; an fzf picker) show nofile buffers — neither is the code
        ;; window a session resolves from. Fall back to the pane's
        ;; source window for both, or the session blinks to nil while
        ;; a float is open and reload-threads wipes the pane empty
        via-source (not (normal-buf (vim.api.nvim_win_get_buf cur)))
        win (if (and via-source pane-source-win
                     (vim.api.nvim_win_is_valid pane-source-win))
                pane-source-win
                cur)
        buf (vim.api.nvim_win_get_buf win)]
    (when (normal-buf buf) (vim.api.nvim_buf_get_name buf))))

(fn source-session []
  (let [name (source-buf-name)]
    (when name (review.session-for name))))

(set M.session-id (fn [] (?. (source-session) :id)))

(fn covers? [t line]
  (and t.line_start t.line_end (>= line t.line_start) (<= line t.line_end)))

(fn threads-at [path line]
  (var found nil)
  (each [_ t (ipairs (or (. threads-by-path path) [])) &until found]
    (when (covers? t line)
      (set found t)))
  (if found [found] []))

(fn fresh [t]
  (var out nil)
  (each [_ th (ipairs all-threads) &until out]
    (when (and t (= (or th.id 0) (or t.id 0)))
      (set out th)))
  out)

(fn index-of [t]
  (accumulate [found nil i th (ipairs all-threads)]
    (or found (when (and t (= th.id t.id)) (- i 1)))))

(fn ensure-current []
  (when (not (fresh current-thread))
    (set current-thread (. all-threads 1))))

(fn stamp-thread [t]
  (let [twin (review.twin (or t.id 0))]
    (set t.twin-kind (when twin twin.kind))
    (set t.conversation (review.conversation-comments (or t.id 0)))
    (each [_ c (ipairs (or t.conversation []))]
      (set c.author-name (or (?. (review.comment-author c) :name) :unknown)))
    (set t.anchor-sha
         (when t.anchor_commit (review.commit-sha t.anchor_commit)))))

(var map-version 0)
(var rendered-sig nil)

(fn conv-sig [t]
  (accumulate [sig "" _ c (ipairs (or t.conversation []))]
    (.. sig (tostring (or c.id 0)) ",")))

(fn map-sig []
  (accumulate [sig "" _ t (ipairs all-threads)]
    (.. sig (tostring (or t.id 0)) ":" (conv-sig t) ";")))

(fn short-sha [sha]
  (if (and sha (>= (length sha) 7)) (sha:sub 1 7) (or sha "?")))

(fn thread-header [base t]
  (let [status (.. (or t.status :open)
                   (or (when (and t.gh_outdated (> (or t.gh_outdated 0) 0))
                         ", outdated") "")
                   (or (when (= :review (or t.twin-kind :local)) " · promoted")
                       ""))
        pos (if (= :file (or t.type :line)) :file
                (.. (or t.line_start "?") "-" (or t.line_end "?")))]
    (string.format "#%d  %s:%s  (%s)  anchor %s" (or t.id 0) base pos status
                   (short-sha t.anchor-sha))))

(fn comment-label [c]
  (string.format "[%s] %s" (or c.source :user) (or c.author-name :unknown)))

(local comment-hls {:posted :MoreMsg
                    :sent :Directory
                    :draft :WarningMsg
                    :agent :Special
                    :github :Identifier})

(fn comment-status [c]
  (let [source (or c.source :user)]
    (if (= :github source) :github
        (= :agent source) :agent
        (or (> (or c.posted 0) 0) c.gh_comment_id) :posted
        (> (or c.sent 0) 0) :sent
        :draft)))

(fn comment-hl [c] (. comment-hls (comment-status c)))

(fn render [path threads]
  (let [lines []
        headers []
        labels []
        base (or (vim.fs.basename (or path "")) "?")]
    (each [i t (ipairs threads)]
      (when (> i 1) (table.insert lines (string.rep "─" pane-width)))
      (table.insert headers {:row (+ (length lines) 1)
                             :hl (thread-hl (or (. t :hl-index) i))
                             :thread t})
      (table.insert lines (thread-header base t))
      (table.insert lines "")
      (each [j c (ipairs (or t.conversation []))]
        (when (> j 1) (table.insert lines ""))
        (table.insert labels {:row (+ (length lines) 1) :hl (comment-hl c)})
        (table.insert lines (comment-label c))
        (each [_ l (ipairs (vim.split (or c.body "") "\n"))]
          (table.insert lines l))))
    (when (> (length threads) 0)
      (table.insert lines "")
      (each [_ l (ipairs pane-keys-footer)]
        (table.insert labels {:row (+ (length lines) 1)})
        (table.insert lines l)))
    {: lines : headers : labels}))

(fn pane-sig [path threads]
  (.. (or path "") "|" (tostring map-version) "|"
      (table.concat (icollect [_ t (ipairs (or threads []))]
                      (tostring (or t.id 0))) ",")))

(fn render-pane [path threads]
  (when (not= (pane-sig path threads) rendered-sig)
    (set rendered-sig (pane-sig path threads))
    (let [buf (vim.api.nvim_win_get_buf pane-win)
          bo (. vim.bo buf)
          {: lines : headers : labels} (render path threads)]
      (set pane-path path)
      (set pane-header-rows headers)
      (vim.api.nvim_buf_clear_namespace buf extmark-ns 0 -1)
      (set bo.modifiable true)
      (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
      (set bo.modifiable false)
      (each [_ h (ipairs headers)]
        (vim.api.nvim_buf_set_extmark buf extmark-ns (- h.row 1) 0
                                      {:line_hl_group h.hl}))
      (each [_ l (ipairs labels)]
        (vim.api.nvim_buf_set_extmark buf extmark-ns (- l.row 1) 0
                                      {:line_hl_group (or l.hl :Comment)})))))

(fn pane-thread-at [row]
  (var t nil)
  (each [_ h (ipairs pane-header-rows) &until (> h.row row)]
    (set t h.thread))
  t)

(fn refresh-pane []
  (when (and pane-win (vim.api.nvim_win_is_valid pane-win))
    (when current-thread (stamp-thread current-thread))
    (set map-version (+ 1 map-version))
    (render-pane pane-path (if current-thread [current-thread] []))))

(fn review-half [t]
  (if (= :review (or t.kind :local))
      t
      (let [twin (review.twin (or t.id 0))]
        (when (and twin (= :review (or twin.kind :local)))
          twin))))

(fn pane-reply []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (let [target (review-half t)]
          (if (not target)
              (vim.notify "codeboomer: thread not promoted — p promotes it first"
                          vim.log.levels.WARN)
              (input.open {:title (string.format " Reply on thread #%d> "
                                                 (or t.id 0))
                           :on-submit (fn [lines]
                                        (when (review.user-reply (or target.id
                                                                     0)
                                                                 (table.concat lines
                                                                               "\n"))
                                          (refresh-pane)))}))))))

(fn pane-agent-reply []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (let [target (if (= :local (or t.kind :local))
                         t
                         (or (review.twin (or t.id 0))
                             (review.ensure-local-twin (or t.id 0))))]
          (if (not target)
              (vim.notify "codeboomer: could not open the conversation"
                          vim.log.levels.ERROR)
              (input.open {:title (string.format " Reply to the agent on thread #%d> "
                                                 (or t.id 0))
                           :on-submit (fn [lines]
                                        (when (review.user-reply (or target.id
                                                                     0)
                                                                 (table.concat lines
                                                                               "\n"))
                                          (refresh-pane)))}))))))

(fn virgin-body [t]
  (let [cs (review.conversation-comments (or t.id 0))]
    (when (= 1 (length cs))
      (let [c (. cs 1)]
        (when (= :user (or c.source :user)) (or c.body ""))))))

(fn first-user-body [t]
  (accumulate [body nil _ c (ipairs (review.conversation-comments (or t.id 0)))]
    (or body (when (= :user (or c.source :user)) (or c.body "")))))

(fn pane-promote []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (= :review (or t.kind :local))
        (vim.notify "codeboomer: this thread is already on github"
                    vim.log.levels.WARN)
        (review.twin (or t.id 0))
        (vim.notify (string.format "codeboomer: thread #%d already promoted"
                                   (or t.id 0))
                    vim.log.levels.WARN)
        (let [session (source-session)
              ctx ((. (require :codeboomer.review-mode) :promote-context) session)]
          (if (not ctx)
              (vim.notify "codeboomer: this branch's session is not bound to a PR — :Codeboomer Review first"
                          vim.log.levels.WARN)
              (and ctx.head-ranges (github.thread-off-diff t ctx.head-ranges))
              (vim.notify "codeboomer: the range falls outside the PR diff — move or resolve the thread first"
                          vim.log.levels.ERROR)
              (let [as-is (virgin-body t)]
                (if as-is
                    (do
                      ;; promote nil-refuses with the specific reason on
                      ;; its own notify — only claim success when it landed
                      (when (review.promote (or t.id 0) as-is ctx.session-id)
                        (refresh-pane)
                        (vim.notify (string.format "codeboomer: thread #%d promoted"
                                                   (or t.id 0))
                                    vim.log.levels.INFO)))
                    (input.open {:title (string.format " Promote thread #%d> "
                                                       (or t.id 0))
                                 :prefill (or (first-user-body t) "")
                                 :on-submit (fn [lines]
                                              (let [body (table.concat lines
                                                                       "\n")]
                                                (when (and (not= ""
                                                                 (vim.trim body))
                                                           (review.promote (or t.id
                                                                               0)
                                                                           body
                                                                           ctx.session-id))
                                                  (refresh-pane)
                                                  (vim.notify (string.format "codeboomer: thread #%d promoted"
                                                                             (or t.id
                                                                                 0))
                                                              vim.log.levels.INFO))))}))))))))

(fn pane-edit []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (let [target (review-half t)]
          (if (not target)
              (vim.notify "codeboomer: thread not promoted — p promotes it first"
                          vim.log.levels.WARN)
              (let [c (. (review.unposted-user-comments (or target.id 0)) 1)]
                (if (not c)
                    (vim.notify "codeboomer: nothing unposted to edit"
                                vim.log.levels.WARN)
                    (input.open {:title (string.format " Edit comment #%d> "
                                                       (or c.id 0))
                                 :prefill (or c.body "")
                                 :on-submit (fn [lines]
                                              (review.update-comment-body (or c.id
                                                                              0)
                                                                          (table.concat lines
                                                                                        "\n"))
                                              (refresh-pane))}))))))))

(fn pane-delete []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (let [cs (review.conversation-comments (or t.id 0))
              c (. cs (length cs))]
          (if (not c)
              (vim.notify "codeboomer: the thread has no messages"
                          vim.log.levels.WARN)
              (or (not= :user (or c.source :user)) (> (or c.sent 0) 0)
                  (> (or c.posted 0) 0) c.gh_comment_id)
              (vim.notify "codeboomer: the last message already left — nothing unsent to delete"
                          vim.log.levels.WARN)
              (do
                (review.delete-comment (or c.id 0))
                (refresh-pane)
                (vim.notify (string.format "codeboomer: deleted the unsent message on thread #%d"
                                           (or t.id 0))
                            vim.log.levels.INFO)))))))

(fn pane-refresh [] (when current-thread (refresh-pane)))

(fn covering-at-source []
  (if (not (and pane-source-win (vim.api.nvim_win_is_valid pane-source-win)
                pane-win (vim.api.nvim_win_is_valid pane-win)))
      nil
      (let [row (?. (vim.api.nvim_win_get_cursor pane-source-win) 1)]
        (threads-at (or pane-path "") (or row 0)))))

(fn pane-resolve []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (let [n (length all-threads)
              successor (when (> n 0)
                          (. all-threads (+ 1 (% (+ (or (index-of t) -1) 1) n))))]
          (review.resolve-thread (or t.id 0))
          (M.reload-threads successor)))))

(var pane-jump nil)

(fn hide-pane []
  (let [win pane-win]
    (set pane-win nil)
    (set rendered-sig nil)
    (when (and win (vim.api.nvim_win_is_valid win))
      (pcall vim.api.nvim_win_close win true))))

(fn open-pane []
  (vim.cmd (string.format "botright %dvnew" pane-width))
  (set pane-win (vim.api.nvim_get_current_win))
  (let [buf (vim.api.nvim_get_current_buf)
        bo (. vim.bo buf)
        wo (. vim.wo pane-win)]
    (set bo.buftype :nofile)
    (set bo.swapfile false)
    (set bo.bufhidden :wipe)
    (set bo.modifiable false)
    (pcall vim.api.nvim_buf_set_name buf pane-buf-name)
    (set wo.wrap true)
    (set wo.linebreak true)
    (set wo.number false)
    (set wo.relativenumber false)
    (set wo.signcolumn :no)
    (set wo.winfixwidth true)
    (vim.keymap.set :n :r pane-reply
                    {:buffer buf :desc "codeboomer: reply on this thread"})
    (vim.keymap.set :n :a pane-agent-reply
                    {:buffer buf
                     :desc "codeboomer: reply to the agent on this thread"})
    (vim.keymap.set :n :p pane-promote
                    {:buffer buf
                     :desc "codeboomer: promote this thread to the PR review"})
    (vim.keymap.set :n :e pane-edit
                    {:buffer buf :desc "codeboomer: edit the promoted comment"})
    (vim.keymap.set :n :d pane-delete
                    {:buffer buf
                     :desc "codeboomer: delete the last unsent message"})
    (vim.keymap.set :n :f pane-refresh
                    {:buffer buf :desc "codeboomer: refresh this thread"})
    (vim.keymap.set :n :q pane-resolve
                    {:buffer buf :desc "codeboomer: resolve this thread"})
    (vim.keymap.set :n :n #(pane-jump 1)
                    {:buffer buf :desc "codeboomer: jump to the next thread"})
    (vim.keymap.set :n :N #(pane-jump -1)
                    {:buffer buf
                     :desc "codeboomer: jump to the previous thread"}))
  (vim.cmd "wincmd p"))

(fn pane-valid? [] (and pane-win (vim.api.nvim_win_is_valid pane-win)))

;; only a source window opens the pane or pulls it into its tab — from
;; anywhere else (a terminal tab, a plugin window) an open pane just
;; re-renders where it is
(fn show-pane [path threads]
  (let [here (source-win? (vim.api.nvim_get_current_win))]
    (when (and here (pane-valid?)
               (not= (vim.api.nvim_win_get_tabpage pane-win)
                     (vim.api.nvim_get_current_tabpage)))
      (hide-pane))
    (when (and here (not (pane-valid?)))
      (open-pane)))
  (when (pane-valid?)
    (render-pane path threads)))

(fn show-current []
  (if current-thread
      (show-pane current-thread.file_path [current-thread])
      (show-pane pane-path [])))

(fn open-on-session []
  (when (> (length all-threads) 0)
    (ensure-current)
    (when (not= (vim.api.nvim_get_current_win) pane-win)
      (set pane-source-win (vim.api.nvim_get_current_win)))
    (show-current)))

(set M.enter-file (fn [bufnr]
                    (when (and (vim.api.nvim_buf_is_valid bufnr)
                               (= bufnr (vim.api.nvim_get_current_buf))
                               (source-win? (vim.api.nvim_get_current_win)))
                      (when (and pane-win (vim.api.nvim_win_is_valid pane-win)
                                 (= (vim.api.nvim_win_get_tabpage pane-win)
                                    (vim.api.nvim_get_current_tabpage)))
                        (set pane-source-win (vim.api.nvim_get_current_win)))
                      (let [path (buf-rel-path bufnr)
                            file-threads (or (. threads-by-path path) [])
                            candidate (if (and current-thread
                                               (= (or current-thread.file_path
                                                      "")
                                                  path))
                                          current-thread
                                          (. file-threads 1))]
                        (when (and candidate
                                   (or (not pane-win)
                                       (not (vim.api.nvim_win_is_valid pane-win))
                                       (not= candidate current-thread)))
                          (set current-thread candidate)
                          (set pane-source-win (vim.api.nvim_get_current_win))
                          (show-current))))))

(fn flash-line [win row]
  (let [buf (vim.api.nvim_win_get_buf win)
        id (vim.api.nvim_buf_set_extmark buf flash-ns (- row 1) 0
                                         {:end_row row
                                          :hl_group :IncSearch
                                          :hl_eol true})]
    (vim.defer_fn (fn []
                    (when (vim.api.nvim_buf_is_valid buf)
                      (pcall vim.api.nvim_buf_del_extmark buf flash-ns id)))
      flash-ms)))

(set pane-jump
     (fn [dir]
       (if (not (and pane-source-win
                     (vim.api.nvim_win_is_valid pane-source-win)))
           (vim.notify "codeboomer: the pane has no code window to jump from"
                       vim.log.levels.WARN)
           (let [n (length all-threads)]
             (if (= 0 n)
                 (vim.notify "codeboomer: no threads to jump to"
                             vim.log.levels.WARN)
                 (let [target (. all-threads
                                 (+ 1
                                    (% (+ (or (index-of current-thread)
                                              (if (> dir 0) -1 0))
                                          dir)
                                       n)))
                       source-buf (vim.api.nvim_win_get_buf pane-source-win)
                       cur-path (buf-rel-path source-buf)
                       target-path (.. (or (git.work-root source-buf) "") "/"
                                       target.file_path)]
                   (let [jump-to (fn []
                                   (when (not= cur-path target.file_path)
                                     (vim.cmd {:cmd :edit :args [target-path]}))
                                   (let [row (math.min (or target.line_start 1)
                                                       (vim.api.nvim_buf_line_count 0))]
                                     (vim.api.nvim_win_set_cursor pane-source-win
                                                                  [row 0])
                                     (vim.cmd "normal! zz")
                                     row))
                         row (vim.api.nvim_win_call pane-source-win jump-to)]
                     (flash-line pane-source-win row))
                   (set current-thread target)
                   (show-pane target.file_path [target])
                   (vim.api.nvim_win_set_cursor pane-win [1 0])))))))

(fn evaluate-at [win]
  (let [buf (vim.api.nvim_win_get_buf win)]
    (when (source-win? win)
      (let [row (?. (vim.api.nvim_win_get_cursor win) 1)
            path (buf-rel-path buf)
            threads (threads-at path (or row 0))]
        (when (> (length threads) 0)
          (set pane-source-win win)
          ;; where ranges overlap the thread on screen stays put — n
          ;; landing on a shared start line must not snap back to the
          ;; earliest covering thread
          (let [cur (fresh current-thread)]
            (set current-thread
                 (if (and cur (= (or cur.file_path "") path)
                          (covers? cur (or row 0)))
                     cur
                     (. threads 1))))
          (show-current))))))

(fn check-now []
  (let [win (vim.api.nvim_get_current_win)]
    (if (= win pane-win)
        (when (and pane-source-win (vim.api.nvim_win_is_valid pane-source-win))
          (evaluate-at pane-source-win))
        (evaluate-at win))))

(fn schedule-check []
  (when timer-id (vim.fn.timer_stop timer-id))
  (set timer-id (vim.fn.timer_start rest-ms check-now)))

(fn idle-refresh []
  (when (M.session-id)
    (M.reload-threads)))

(fn schedule-db-refresh []
  (when db-refresh-timer (vim.fn.timer_stop db-refresh-timer))
  (set db-refresh-timer (vim.fn.timer_start db-refresh-ms idle-refresh)))

(fn reconcile-pane [?prefer]
  (when (and pane-win (vim.api.nvim_win_is_valid pane-win))
    (set current-thread (or (fresh current-thread)
                            (fresh (. (covering-at-source) 1)) (fresh ?prefer)
                            (. all-threads 1)))
    (show-current)))

(var loaded-session-id nil)

(fn maybe-reload-session []
  (let [sid (M.session-id)]
    (when (not= sid loaded-session-id)
      (M.reload-threads))))

(fn M.reload-threads [?prefer]
  (let [sid (M.session-id)
        before (map-sig)]
    (set loaded-session-id sid)
    (set threads-by-path {})
    (set all-threads (if sid (review.threads-for-session sid) []))
    (each [_ t (ipairs all-threads)] (stamp-thread t))
    (each [_ t (ipairs all-threads)]
      (let [path (or t.file_path "")
            peers (vim.list_extend (or (. threads-by-path path) []) [t])]
        (set t.hl-index (length peers))
        (tset threads-by-path path peers)))
    (when (not= before (map-sig))
      (set map-version (+ 1 map-version))
      (reconcile-pane ?prefer)
      (schedule-check))))

(fn attach-autocmds []
  (vim.api.nvim_create_augroup augroup-name {:clear true})
  (vim.api.nvim_create_autocmd :VimEnter
                               {:group augroup-name
                                :callback (fn []
                                            (maybe-reload-session)
                                            (open-on-session))})
  (vim.api.nvim_create_autocmd :BufEnter
                               {:group augroup-name
                                :callback (fn [ev]
                                            (maybe-reload-session)
                                            (M.enter-file ev.buf)
                                            (schedule-check)
                                            (schedule-db-refresh))})
  (vim.api.nvim_create_autocmd [:WinEnter
                                :TabEnter
                                :CursorMoved
                                :CursorMovedI
                                :FocusGained]
                               {:group augroup-name
                                :callback (fn []
                                            (schedule-check)
                                            (schedule-db-refresh))})
  (vim.api.nvim_create_autocmd :WinClosed
                               {:group augroup-name
                                :callback (fn [ev]
                                            (when (= pane-win
                                                     (tonumber ev.match))
                                              (set pane-win nil)
                                              (set rendered-sig nil)))})
  (vim.api.nvim_create_autocmd :User
                               {:group augroup-name
                                :pattern [:CodeboomerAnnotated
                                          :CodeboomerSessionReset
                                          :CodeboomerImported]
                                :callback #(M.reload-threads)}))

(set M.open (fn []
              (M.reload-threads)
              (open-on-session)
              (check-now)))

(attach-autocmds)

M
