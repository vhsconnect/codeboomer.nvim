(global vim vim)
(local config (require :compis.config))
(local curl (require :plenary.curl))

(fn get-api-key [provider-name]
  (let [env-var (if (= provider-name :openrouter) :OPENROUTER_API_KEY
                    (= provider-name :openai) :OPENAI_API_KEY
                    (= provider-name :claude) :ANTHROPIC_API_KEY
                    nil)]
    (if env-var
        (os.getenv env-var)
        nil)))

(fn build-messages [system-prompt user-prompt]
  [{:role :system :content system-prompt} {:role :user :content user-prompt}])

(fn build-curl-args [provider-name messages]
  (let [provider (config.get_provider provider-name)
        api-key (get-api-key provider-name)
        endpoint (provider.endpoint:gsub "/+$" "")
        url (.. endpoint :/chat/completions)
        headers {:Content-Type :application/json}
        headers (if api-key
                    (vim.tbl_deep_extend :force headers
                                         {:Authorization (.. "Bearer " api-key)})
                    headers)
        body (vim.json.encode {:model provider.model
                               : messages
                               :stream false
                               :temperature (or provider.temperature 0)
                               :max_tokens (or provider.max_tokens 4096)})]
    {: url : headers : body}))

(fn complete [system-prompt user-prompt callback]
  (let [provider-name config.config.provider
        api-key (get-api-key provider-name)]
    (if (not api-key)
        (callback nil (.. "compis: API key not found for provider "
                          provider-name))
        (let [messages (build-messages system-prompt user-prompt)
              args (build-curl-args provider-name messages)]
          (curl.post args.url
                     {:headers args.headers
                      :body args.body
                      :callback (fn [res]
                                  (if (not= res.status 200)
                                      (callback nil
                                                (.. "compis: request failed – HTTP "
                                                    res.status " – " res.body))
                                      (let [(ok parsed) (pcall vim.json.decode
                                                               res.body)]
                                        (if (not ok)
                                            (callback nil
                                                      (.. "compis: failed to parse response – "
                                                          parsed))
                                            (callback parsed nil)))))})))))

{: complete : get-api-key : build-messages : build-curl-args}
