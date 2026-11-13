module.exports = {
    apps: [
        {
            name: "keepalive",
            script: "/bin/sleep",
            args: "infinity",
            interpreter: "none",
        },
        // {
        //     name: "example",
        //     cwd: "/var/www/example",
        //     script: "node_modules/next/dist/bin/next",
        //     args: "dev -H 0.0.0.0 -p 3000",
        //     autorestart: true,
        // },
    ]
};
