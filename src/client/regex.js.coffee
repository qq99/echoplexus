# utility: a container of useful regexes arranged into some a rough taxonomy
module.exports.REGEXES =
  urls:
    image: /(\b(https?|http):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|].(jpeg|jpg|png|bmp|gif|svg))/gi
    youtube: /((https?:\/\/)?(www\.)?youtu((?=\.)\.be\/|be\.com\/watch.*v=)([\w\d\-_]*))/gi
    all_others: /(\b(https?|http):(\/\/|&#x2F;&#x2F;)[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|;])/gi

  users:
    mentions: /(@[^\b\s]*)/gi

  commands:
    nick: /^\/(nick|n) /
    register: /^\/register/
    identify: /^\/(identify|id)/
    topic: /^\/(topic) /
    broadcast: /^\/(broadcast|bc) /
    failed_command: /^\//
    private: /^\/private/
    public: /^\/public/
    help: /^\/help/
    password: /^\/(password|pw)/
    private_message: /^\/(pm|w|whisper|t|tell) /
    join: /^\/(join|j)/
    leave: /^\/leave/
    pull_logs: /^\/(pull|p|sync|s) /
    set_color: /^\/(color|c) /
    edit: /^(\/edit) #?(\d*) /
    chown: /^\/chown /
    chmod: /^\/chmod /
    reply: /(>>|&gt;&gt;)(\d+)/g
    github: /^\/github /

  github_subcommands:
    track: /^track/

  colors:
    hex: /^#?([a-f0-9]{6}|[a-f0-9]{3})$/i # matches 3 and 6-char hex colour codes, optional #
