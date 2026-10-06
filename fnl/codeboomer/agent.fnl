;; [nfnl] codeboomer/agent.fnl
;; The CLI half of the agent bridge: lets a review agent outside nvim
;; answer comment threads and open threads of its own. Agents never
;; type nvim incantations — they call the generated `codeboomer-agent`
;; shim (see ensure-shim), which runs this module headlessly.
;; Arguments arrive through the CODEBOOMER_AGENT_ARGS env var,
;; sidestepping nvim's own argument handling entirely.
;;
;;   codeboomer-agent reply <thread-id> <answer text...>
;;   codeboomer-agent comment <file> <line>[-<line>] <text...>
;;   codeboomer-agent file-comment <file> <text...>
(global vim vim)

(local git (require :codeboomer.git))
(local review (require :codeboomer.review))

(local M {})

(local shim-path (.. (vim.fn.stdpath :data) :/codeboomer-agent))

;; the one meta-line every flush appends for the receiving agent —
;; short, imperative, stable: the thread ids arrive inline in each
;; annotation header, this tells it what to do with them
(fn M.reply-instructions []
  (.. "Reply to each thread above. Keep your responses in the thread short and consice and use the harnass to provide detail. Answer in the thread with: "
      shim-path " reply <thread-id> <text>\n"))

;; the launch prompt — short on purpose: {scope} says what to review,
;; the shim's own help carries the API, the agent's own output carries
;; the detail
(fn M.review-prompt [scope]
  (.. scope " Post your findings with " shim-path
      " — run it with `help` first."
      " Keep each comment to one or two sentences; put the detailed reasoning in your own output here."
      " Don't switch branches while reviewing."))

(local usage "usage: codeboomer-agent reply <thread-id> <text>
       codeboomer-agent comment <file> <line>[-<line>] <text>
       codeboomer-agent file-comment <file> <text>")

;; the agent's own entry point for discovering the tool cold: given
;; nothing but the shim's path, `help`/`-h`/`--help`/no args at all
;; print this instead of failing
(local help-text (.. usage "\n\n" "codeboomer-agent posts a review agent's comments into codeboomer's
" "comment threads from outside nvim — thread ids arrive inline
" "wherever a review's annotations were sent to you.

" "verbs:\n" "  reply <thread-id> <text...>   reply to an existing, open thread.
" "                                Fails if the thread doesn't exist or
" "                                is resolved/deleted.
" "  comment <file> <line>[-<line>] <text...>
" "                                start a new thread on a line or an
" "                                inclusive line range of <file>.
" "  file-comment <file> <text...> start a new thread on <file> as a
" "                                whole.
" "  help | -h | --help            show this message.

" "<file> is relative to the current directory's work tree (absolute
" "paths inside it work too); lines count from 1 as the file reads on
" "disk — comment on committed code: a range edited since HEAD can't
" "be promoted to the PR. <text> is every argument after the last
" "positional one, joined with spaces — no quoting needed. Arguments
"
                     "split on every space, so a <file> containing one can't be named.

" "exit status: 0 on success, 1 on failure (the message says why).
"))

;; the work tree file an agent named, as a repo-relative path plus its
;; lines — nil and the reason when it escapes the tree or is missing
(fn resolve-file [path]
  (let [root (git.work-root (vim.fn.getcwd))
        real-root (when root (vim.uv.fs_realpath root))
        joined (if (vim.startswith path "/") path
                   (vim.fs.joinpath (vim.fn.getcwd) path))
        real (vim.uv.fs_realpath joined)
        kind (?. (when real (vim.uv.fs_stat real)) :type)]
    (case (values real-root real kind)
      (nil) (values nil "not inside a git work tree")
      (_ nil) (values nil (.. "no such file: " path))
      (where (r f) (not (vim.startswith f (.. r "/"))))
      (values nil (.. "file is outside the work tree: " path))
      (r f :file) {:rel (f:sub (+ 2 (length r))) :lines (vim.fn.readfile f)}
      _ (values nil (.. "not a file: " path)))))

(fn parse-range [spec]
  (let [single (tonumber (string.match (or spec "") "^(%d+)$"))
        (from to) (string.match (or spec "") "^(%d+)-(%d+)$")]
    (if single (values single single) (values (tonumber from) (tonumber to)))))

(local no-session "no review session — run from a checked-out branch")

(fn reply [args]
  (let [thread-id (tonumber (. args 2))
        body (table.concat (vim.list_slice args 3) " ")]
    (if (not thread-id) (values false "thread id must be a number") (= body "")
        (values false "missing answer text")
        (let [id (review.agent-reply thread-id body)]
          (if id
              (values true
                      (string.format "posted reply to thread #%d (comment %d)"
                                     thread-id id))
              ;; review.agent-reply has already said why
              (values false "reply rejected"))))))

(fn line-comment [args]
  (let [(file err) (resolve-file (or (. args 2) ""))
        (from to) (parse-range (. args 3))
        body (table.concat (vim.list_slice args 4) " ")]
    (if (not file) (values false err) (not from)
        (values false "lines must look like 12 or 12-18")
        (or (< from 1) (< to from) (> to (length file.lines)))
        (values false
                (string.format "lines %d-%d out of range — %s has %d lines"
                               from to file.rel (length file.lines)))
        (= body "") (values false "missing comment text")
        (let [sid (review.ensure-session)
              snapshot (table.concat (vim.list_slice file.lines from to) "\n")]
          (if (not sid) (values false no-session)
              (values true
                      (string.format "opened thread #%d on %s:%d-%d"
                                     (review.agent-comment sid file.rel from to
                                                           snapshot body)
                                     file.rel from to)))))))

(fn file-comment [args]
  (let [(file err) (resolve-file (or (. args 2) ""))
        body (table.concat (vim.list_slice args 3) " ")]
    (if (not file) (values false err) (= body "")
        (values false "missing comment text")
        (let [sid (review.ensure-session)]
          (if (not sid) (values false no-session)
              (values true (string.format "opened thread #%d on %s"
                                          (review.agent-file-comment sid
                                                                     file.rel
                                                                     body)
                                          file.rel)))))))

(local verbs {: reply :comment line-comment : file-comment})

;; one verb, no process exit — main's testable core. Returns ok and
;; the message to print, or false and why it failed
(fn M.run [args]
  (let [verb (. verbs (or (. args 1) ""))]
    (if verb (verb args)
        (values false
                "expected reply, comment or file-comment as the first argument"))))

(fn M.main []
  (let [args (vim.split (or (os.getenv :CODEBOOMER_AGENT_ARGS) "") " "
                        {:trimempty true})
        verb (. args 1)]
    (if (or (not verb) (= verb :help) (= verb :-h) (= verb :--help))
        (do
          (print help-text)
          (os.exit 0 true))
        (let [(ok msg) (M.run args)]
          (if ok
              (do
                (print (.. "codeboomer-agent: " msg))
                (os.exit 0 true))
              (do
                (print (.. "codeboomer-agent: " msg "\n" usage
                           "\nrun `codeboomer-agent help` for details"))
                (os.exit 1 true)))))))

;; the shim bakes in the running nvim's environment (plugin root,
;; LD_LIBRARY_PATH for libsqlite3) so the agent needs nothing but the
;; path itself; regenerated whenever its content drifts
(fn shim-content []
  (let [entry (?. (vim.api.nvim_get_runtime_file :plugin/codeboomer.lua false)
                  1)]
    (when entry
      (let [root (vim.fs.dirname (vim.fs.dirname entry))
            ld (or (os.getenv :LD_LIBRARY_PATH) "")]
        (string.format "#!/usr/bin/env bash
# codeboomer-agent — post review comments from outside nvim.
# GENERATED by codeboomer.nvim on load — edits are overwritten.
set -euo pipefail
export CODEBOOMER_PATH='%s'
export LD_LIBRARY_PATH='%s'
export CODEBOOMER_AGENT_ARGS=\"$*\"
exec nvim --headless -u NONE --cmd \"set rtp^=${CODEBOOMER_PATH}\" -c 'lua require(\"codeboomer.agent\").main()' -c 'qa!'
" root ld)))))

;; write the shim only when its content differs — after the first
;; generation this is one cheap readfile per nvim start
(fn M.ensure-shim []
  (let [content (shim-content)]
    (when content
      (let [lines (vim.split content "\n" {:plain true})
            (ok existing) (pcall vim.fn.readfile shim-path)
            same (and ok (= (type existing) :table)
                      (= (table.concat (or existing []) "\n")
                         (table.concat lines "\n")))]
        (when (not same)
          (vim.fn.writefile lines shim-path)
          ;; 0o755 — uv chmod takes the mode in decimal
          (pcall vim.loop.fs_chmod shim-path 493))))))

(M.ensure-shim)

M
