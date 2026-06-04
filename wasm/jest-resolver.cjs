/**
 * Custom Jest resolver for ESM packages linked via `file:` deps.
 *
 * Jest's default resolver can't follow symlinks whose target lives outside
 * the project root (a common situation with local `file:` dependencies during
 * development).  In CI the package is installed from the registry into
 * node_modules normally, so the default resolver succeeds there.
 *
 * Strategy: try default resolution first; if it throws, resolve the symlink
 * in node_modules to its real path and read the package.json `main` field.
 */

const path = require('path');
const fs   = require('fs');

module.exports = function resolver(request, options) {
    try {
        return options.defaultResolver(request, options);
    } catch (err) {
        // Only attempt fallback for scoped/namespaced packages that look like
        // installed deps (not relative paths).
        if (!request.startsWith('.') && !request.startsWith('/')) {
            const parts    = request.startsWith('@')
                ? request.split('/').slice(0, 2)   // ['@scope', 'pkg']
                : [request.split('/')[0]];           // ['pkg']
            const linkPath = path.join(options.rootDir, 'node_modules', ...parts);

            if (fs.existsSync(linkPath)) {
                try {
                    const realDir = fs.realpathSync(linkPath);
                    const pkgJson = JSON.parse(
                        fs.readFileSync(path.join(realDir, 'package.json'), 'utf8')
                    );
                    const main = pkgJson.main || 'index.js';
                    return path.join(realDir, main);
                } catch (_) {
                    // fall through to re-throw original error
                }
            }
        }
        throw err;
    }
};
