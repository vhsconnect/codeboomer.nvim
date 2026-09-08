(global vim vim)
(local git (require :codeboomer.git))
(local sqlite (require :codeboomer.sqlite))
(local M {})

(fn with-user []
  (let [email (git.user-email)
        entry? (sqlite.user:get {:where {: email}})]
    (if (. entry? 1) (?. entry? 1 :id)
        (sqlite.user:insert {:name (git.user-name) : email}))))

(fn with-repo []
  (let [repo-path (git.repo-root)
        entry? (sqlite.repo:get {:where {:path repo-path}})]
    (if (. entry? 1) (?. entry? 1 :id) (sqlite.repo:insert {:path repo-path}))))

(fn with-commit [repo-id]
  (let [commit-hash (git.head-sha)
        entry? (sqlite.commit:get {:where {:hash commit-hash}})]
    (if (. entry? 1) (?. entry? 1 :id)
        (sqlite.commit:insert {:hash commit-hash :repo repo-id}))))

(fn prn-debug [x] (print x) x)

(fn M.user-comment [session-id file-path line-start line-end code body]
  ;; we can optimize this later
  (let [user-id (with-user)
        repo-id (with-repo)
        commit-id (with-commit repo-id)
        thread-id (sqlite.thread:insert {:session_id session-id
                                         :file_path file-path
                                         :line_start line-start
                                         :line_end line-end
                                         :code_snapshot code
                                         :anchor_commit commit-id
                                         :status :open
                                         :created_by user-id})]
    (sqlite.comments:insert {:thread_id thread-id
                             :author_id (prn-debug user-id)
                             : body
                             :commit_id commit-id})))

(fn M.get-sessions []
  (sqlite.session:get {:where {:repo_id (with-repo)}}))

(fn M.create-session []
  (let [repo-id (with-repo)]
    (sqlite.session:insert {:name :session1
                            :branch (git.branch-name)
                            :head_commit (with-commit repo-id)
                            :repo_id repo-id})))

M
