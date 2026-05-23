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

(fn is-ollama? [provider-name]
  (= provider-name :ollama))

(fn build-openai-args [provider-name messages]
  (let [provider (config.get_provider provider-name)
        api-key (get-api-key provider-name)
        endpoint (provider.endpoint:gsub "/+$" "")
        url (.. endpoint :/chat/completions)
        headers {:Content-Type :application/json
                 :Authorization (.. "Bearer " api-key)}
        body (vim.json.encode {:model provider.model
                               : messages
                               :stream false
                               :temperature (or provider.temperature 0)
                               :max_tokens (or provider.max_tokens 4096)})]
    {: url : headers : body}))

(fn build-ollama-args [provider-name system-prompt user-prompt]
  (let [provider (config.get_provider provider-name)
        endpoint (provider.endpoint:gsub "/+$" "")
        url (.. endpoint :/api/generate)
        headers {:Content-Type :application/json}
        body (vim.json.encode {:model provider.model
                               :prompt (.. (or system-prompt "") "\n\n"
                                           user-prompt)
                               :stream false
                               :temperature (or provider.temperature 0)})]
    {: url : headers : body}))

(fn build-curl-args [provider-name messages system-prompt user-prompt]
  (if (is-ollama? provider-name)
      (build-ollama-args provider-name system-prompt user-prompt)
      (build-openai-args provider-name messages)))

(fn extract-content [provider-name data]
  (if (is-ollama? provider-name)
      (?. data :response)
      (?. data :choices 1 :message :content)))

(fn complete [system-prompt user-prompt callback]
  (let [provider-name config.config.provider
        api-key (get-api-key provider-name)
        ollama? (is-ollama? provider-name)]
    (if (and (not api-key) (not ollama?))
        (callback nil (.. "compis: API key not found for provider "
                          provider-name))
        (let [messages (build-messages system-prompt user-prompt)
              args (build-curl-args provider-name messages system-prompt
                                    user-prompt)]
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

{: complete : get-api-key : build-messages : build-curl-args : extract-content}
