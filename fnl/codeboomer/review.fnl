(global vim vim)
(local git (require :codeboomer.git))
(local sqlite (require :codeboomer.sqlite))
(local M {})

(fn with-user []
  (let [email (git.user-email)
        entry? (sqlite.user:get {:where {: email}})]
    (if entry? entry?.id (sqlite.user:insert {:name (git.user-name) : email}))))

(fn with-repo []
  (let [repo-path (git.repo-root)
        entry? (sqlite.repo:get {:where {:path repo-path}})]
    (if entry? entry?.id (sqlite.repo:insert {:path repo-path}))))

(fn with-commit [repo-id]
  (let [commit-hash (git.head-sha)
        entry? (sqlite.commit:get {:where {:hash commit-hash}})]
    (if entry? entry?.id
        (sqlite.commit:insert {:hash commit-hash :repo repo-id}))))

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
    (sqlite.comment:insert {:thread_id thread-id
                            :author_id user-id
                            : body
                            :commit commit-id})))

M
