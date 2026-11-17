(local helpers (require :cb_helpers))

(local {: clear : eq} helpers)

(local review-mode (helpers.module :codeboomer.review-mode))

(helpers.env)

(describe :parse-ranges
          (fn []
            (before_each (fn []
                           (clear)
                           (helpers.setup-codeboomer)))
            (it "collects the + side of every hunk per file"
                (fn []
                  (eq {:a.txt [[3 5] [20 20]] :b.txt [[1 2]]}
                      (review-mode.parse-ranges (table.concat ["+++ b/a.txt"
                                                               "@@ -3,2 +3,3 @@"
                                                               "@@ -19 +20 @@"
                                                               "+++ b/b.txt"
                                                               "@@ -0,0 +1,2 @@"]
                                                              "\n")))))
            (it "skips pure deletions and deleted files"
                (fn []
                  (eq {}
                      (review-mode.parse-ranges (table.concat ["+++ /dev/null"
                                                               "@@ -1,4 +0,0 @@"
                                                               "+++ b/a.txt"
                                                               "@@ -8,2 +7,0 @@"]
                                                              "\n")))))
            (it "tolerates a missing diff"
                (fn []
                  (eq {} (review-mode.parse-ranges nil))))))
