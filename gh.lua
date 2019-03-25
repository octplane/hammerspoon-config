
function login_keychain(name)
    -- 'name' should be saved in the login keychain
    local cmd="/usr/bin/security 2>&1 >/dev/null find-generic-password -gl " .. name .. " | sed -En '/^password: / s,^password: \"(.*)\"$,\\1,p'"
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return (result:gsub("^%s*(.-)%s*$", "%1"))
end



local obj = {}

function obj:get_query(query)
 query_string = '{"query": "{ search(query: \\"%s\\", type: ISSUE, first: 100) { issueCount edges { node { ... on PullRequest { repository { nameWithOwner } author { login } createdAt number url title labels(first:100) { nodes { name } } } } } }}"}'

  return string.format(query_string, query)

end

function obj:query(q)
  header = {Authorization="Bearer " .. self.token}
  return hs.http.doRequest(self.endpoint, "POST", self:get_query(q), header)
end

obj.endpoint = "https://api.github.com/graphql"
obj.token = login_keychain("GITHUB_API_TOKEN")


return obj

