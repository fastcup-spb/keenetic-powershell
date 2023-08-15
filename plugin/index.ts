 let auth = (login, password) => (
   
   
   return {
                login: login,
                password: sha256(token + md5(login + ':' + realm + ':' + password))
            })

