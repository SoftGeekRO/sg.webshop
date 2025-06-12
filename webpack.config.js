/*
 * Copyright (c) 2025-2025 SoftGeek. All rights reserved.
 * sg.webShop - Online store with CakePHP vanilla
 * Repository: https://github.com/SoftGeekRO/sg.webShop main
 * Author: SoulRaven <dev@softgeek.ro>
 * License: AGPL-3.0-or-later (See LICENSE file)
 * Last Modified: 23-05-2025 18:12:25 EEST
 */

const path = require('path');
const fs = require('fs');

const webpack = require('webpack');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const {CleanWebpackPlugin} = require('clean-webpack-plugin');
const {WebpackManifestPlugin} = require('webpack-manifest-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const RemoveEmptyScriptsPlugin = require('webpack-remove-empty-scripts');
const autoprefixer = require('autoprefixer');

const isProd = process.env.NODE_ENV === 'production';

// 🔁 Shared output paths
const outputPath = path.resolve(__dirname, 'resources', 'dist',  'wp');

// Utility functions for naming
function getPackageFolderName(filePath) {
  const parts = filePath.split(path.sep);
  const nodeModulesIndex = parts.indexOf('node_modules');

  if (nodeModulesIndex >= 0) {
    const pkg = parts[nodeModulesIndex + 1];
    if (pkg.startsWith('@')) {
      const scopedPkg = parts[nodeModulesIndex + 2];
      return `${pkg.slice(1)}-${scopedPkg}`;
    }
    return pkg;
  }
  return 'local'; // fallback for files not in node_modules
}

const sanitizePackageName = (resourcePath) => {
  const parts = resourcePath.split(path.sep);
  const index = parts.indexOf('node_modules');

  if (index !== -1) {
    const scope = parts[index + 1];
    const name = parts[index + 2];

    if (scope && scope.startsWith('@')) {
      return `${scope.slice(1)}-${name}`;
    }

    return scope;
  }

  return 'local';
};

// 🔧 MAIN APP CONFIG
const appConfig = {
  name: 'appConfig',
  mode: isProd ? 'production' : 'development',
  entry: {
    main: path.resolve(__dirname, 'resources', 'webpack', 'js', 'main.js'),
    style: path.resolve(__dirname, 'resources', 'webpack', 'scss', 'style.scss'),
    bootstrap: path.resolve(__dirname, 'resources', 'webpack', 'scss', 'bootstrap.scss'),
    "admin-css": path.resolve(__dirname, 'resources', 'webpack', 'scss', 'admin.scss'),
    "admin-js": path.resolve(__dirname, 'resources', 'webpack', 'js', 'admin.js'),
    "admin-lte-css": path.resolve(__dirname, 'resources', 'webpack', 'scss', 'admin-lte.scss'),
    "admin-lte-js": path.resolve(__dirname, 'resources', 'webpack', 'js', 'admin-lte.js'),
    tagifyCss: path.resolve(__dirname, 'resources', 'webpack', 'scss', 'tagify', 'tagify.scss'),
    tagifyJs: path.resolve(__dirname, 'resources', 'webpack', 'js', 'tagify.js'),
    fontAwesome: path.resolve(__dirname, 'resources', 'webpack', 'scss', 'font-awesome.scss'),
  },
  output: {
    filename: isProd ? 'js/[name].[contenthash].js' : 'js/[name].js',
    assetModuleFilename: 'assets/[name][ext][query]',
    path: outputPath,
    publicPath: '/static/wp', // necessary for dynamic loading
    clean: true,
    asyncChunks: true // @TODO: test if is working right on production
  },
  externalsType: 'commonjs',
  externals: {
    'ts-loader': 'ts-loader',
    jquery: "jQuery",
    Tagify: 'Tagify',
  },

  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: {
          loader: 'ts-loader',
          options: {
            allowTsInNodeModules: true,  // Important for compiling node_modules TS
            onlyCompileBundledFiles: true, // Only compile files that are actually bundled
            transpileOnly: true             // Skip type checking (faster builds)
          }
        }
      },
      {
        test: /\.(js|jsx|tsx|ts)$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: [
              ['@babel/preset-env', {
                  targets: 'defaults'
                }
              ],
              ["@babel/preset-typescript"]
            ],
            plugins: [
              "@babel/plugin-transform-class-properties",
              "@babel/plugin-syntax-object-rest-spread"
            ]
          }
        }
      },
      {
        test: /\.(scss|css)$/i,
        use: [
          {
            loader: MiniCssExtractPlugin.loader,
            options: {
              publicPath: '../' // optional
            }
          },
          {
            // Interprets `@import` and `url()` like `import/require()` and will resolve them
            loader: 'css-loader'
          },
          {
            // Loader for webpack to process CSS with PostCSS
            loader: 'postcss-loader',
            options: {
              postcssOptions: {
                plugins: [
                  autoprefixer
                ]
              }
            }
          },
          {
            // Loads a SASS/SCSS file and compiles it to CSS
            loader: 'sass-loader',
            options: {
              sassOptions: {
                // Optional: Silence Sass deprecation warnings. See note below.
                silenceDeprecations: [
                  'mixed-decls',
                  'color-functions',
                  'global-builtin',
                  'import'
                ]
              }
            }
          }
        ]
      },
      // Images
      {
        test: /\.(png|jpe?g|svg|gif|webp)$/i,
        type: 'asset/resource',
        generator: {
          //filename: 'images/[name][ext][query]'
          filename: (pathData) => {
            const pkg = getPackageFolderName(pathData.filename),
              fileName = path.basename(pathData.filename);
            return `img/${pkg}/${fileName}`;
          }
        }
      },
      {
        mimetype: 'image/svg+xml',
        //scheme: 'data',
        type: 'asset/resource',
        generator: {
          filename: (pathData) => {
            return 'icons/[name][ext]';
          }
        }
      },
      // Fonts
      // For woff/woff2 fonts
      {
        test: /\.woff2?(\?v=[0-9]\.[0-9]\.[0-9])?$/,
        type: 'asset/resource',
        generator: {
          //filename: 'fonts/[name][ext][query]' // Output path
          filename: (pathData) => {
            const pkg = getPackageFolderName(pathData.filename);
            const fileName = path.basename(pathData.filename);
            return `fonts/${pkg}/${fileName}`;
          }
        }
      },
      // For ttf/eot/svg fonts
      {
        test: /\.(ttf|eot|svg)(\?[\s\S]+)?$/,
        type: 'asset/resource',
        generator: {
          //filename: 'fonts/[name][ext][query]'
          filename: (pathData) => {
            const pkg = getPackageFolderName(pathData.filename);
            const fileName = path.basename(pathData.filename);
            return `fonts/${pkg}/${fileName}`;
          }
        }
      },
      // {
      //   test: /\.(woff2?|eot|ttf|otf)$/i,
      //   type: 'asset/resource',
      //   generator: {
      //     filename: (pathData) => {
      //       const pkg = getPackageFolderName(pathData.filename);
      //       const fileName = path.basename(pathData.filename);
      //       return `fonts/${pkg}/${fileName}`;
      //     }
      //   }
      // }
    ]
  },

  optimization: {
    splitChunks: {
      chunks: 'all',
      cacheGroups: {
        jqueryUi: {
          test: /[\\/]node_modules[\\/]jquery-ui[\\/]/,
          name: 'vendor/jquery-ui',
          chunks: 'all',
          enforce: true
        },
        bootstrap: {
          test: /[\\/]node_modules[\\/]bootstrap[\\/]/,
          name: 'vendor/bootstrap',
          chunks: 'all',
          enforce: true
        },
        // Add more vendors as needed
        defaultVendors: {
          test: /[\\/]node_modules[\\/]/,
          name(module) {
            const pkg = sanitizePackageName(module.identifier());
            return `vendor/${pkg}`;
          },
          chunks: 'all',
          enforce: true,
          priority: -10
        },
        default: false
      }
    }
  },

  plugins: [
    new CleanWebpackPlugin({
      verbose: false,
      cleanOnceBeforeBuildPatterns: ['**/*', '!loader.js', '!loader.*.js'],
      cleanAfterEveryBuildPatterns: []
    }),
    new RemoveEmptyScriptsPlugin(),
    new MiniCssExtractPlugin({
      filename: (pathData) => {
        let name = pathData.chunk.name || 'main';

        // Strip "vendor-" prefix
        name = name.replace(/^vendor/, '');

        // Flatten scoped packages like @popperjs/core → popperjs-core
        name = name.replace(/^@/, '').replace(/\//g, '-');

        // If the name starts with a dash, remove it
        name = name.replace(/^[-]/, '');

        return isProd ? `css/${name}.[contenthash].css` : `css/${name}.css`;
      },
      chunkFilename: isProd ? 'css/[name].[contenthash].css' : 'css/[name].css'
    }),
    new WebpackManifestPlugin({
      fileName: 'manifest.json',
      publicPath: 'wp',
      generate: (seed, files) => {
        const manifest = {};
        files.forEach(file => {
          manifest[file.name] = file.path;
        });
        return manifest;
      }
    }),
    new CopyWebpackPlugin({
      patterns: [
        {
          from: path.resolve(__dirname, 'node_modules/bootstrap-icons/font/bootstrap-icons.css'),
          to: path.resolve(__dirname, 'resources', 'dist', 'wp', 'css', 'bootstrap-icons.css')
        },
        {
          from: path.resolve(__dirname, 'node_modules/bootstrap-icons/font/fonts'),
          to: path.resolve(__dirname, 'resources', 'dist', 'wp', 'fonts')
        }
        // {
        //   from: path.resolve(__dirname, 'src/assets'),
        //   to: path.resolve(__dirname, 'dist/assets'), // or wherever your output path is
        //   noErrorOnMissing: true
        // },
        // {
        //   from: path.resolve(__dirname, 'src/assets/img'),
        //   to: path.resolve(__dirname, 'dist/img'), // or wherever your output path is
        //   noErrorOnMissing: true
        // }
      ]
    }),
    new webpack.ProvidePlugin({
      $: 'jquery',      // Automatically inject `$` where used
      _: 'lodash',
    })
  ],

  devtool: isProd ? false : 'source-map',

  devServer: {
    static: {
      directory: path.join(__dirname, 'dist')
    },
    compress: true,
    port: 3000,
    hot: true,
    open: true
  },

  resolve: {
    alias: {
      '@js': path.resolve(__dirname, 'src/js'),
      '@scss': path.resolve(__dirname, 'src/scss')
    },
    extensions: ['.tsx', '.ts', '.js', 'jsx', '.scss']
  },
  watch: true, // 🔁 Enable watching
  watchOptions: {
    ignored: /node_modules/,
    aggregateTimeout: 300,
    poll: 500 // or set to `false` to use native file system events
  }
};

module.exports = (env = {}) => {
  const targets = {
    //loader: loaderConfig,
    app: appConfig
  };

  if (env.target && targets[env.target]) {
    return targets[env.target];
  }

  return [appConfig]; // fallback
};
