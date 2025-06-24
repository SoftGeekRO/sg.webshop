/*
 * Copyright (c) 2025-2025 SoftGeek. All rights reserved.
 * sg.webShop - Online store with CakePHP vanilla
 * Repository: https://github.com/SoftGeekRO/sg.webShop main
 * Author: SoulRaven <dev@softgeek.ro>
 * License: AGPL-3.0-or-later (See LICENSE file)
 * Last Modified: 23-05-2025 18:12:25 EEST
 */

require('dotenv').config({ path: './.env' });

const path = require('path'),

  webpack = require('webpack'),
  MiniCssExtractPlugin = require('mini-css-extract-plugin'),
  {CleanWebpackPlugin} = require('clean-webpack-plugin'),
  {WebpackManifestPlugin} = require('webpack-manifest-plugin'),
  CopyWebpackPlugin = require('copy-webpack-plugin'),
  RemoveEmptyScriptsPlugin = require('webpack-remove-empty-scripts'),
  { SubresourceIntegrityPlugin } = require('webpack-subresource-integrity'),
  autoprefixer = require('autoprefixer'),

  isProd = process.env.NODE_ENV === 'production',

  publicPath = process.env.STATIC_SUBDOMAIN + 'wp/',

  // 🔁 Shared output paths
  outputPath = path.resolve(__dirname, 'resources', 'dist',  'wp');


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
    main: [
      path.resolve(__dirname, 'resources', 'webpack', 'js', 'main.js'),
      path.resolve(__dirname, 'resources', 'webpack', 'scss', 'main.scss'),
    ],
    admin: [
      path.resolve(__dirname, 'resources', 'webpack', 'js', 'admin.js'),
      path.resolve(__dirname, 'resources', 'webpack', 'scss', 'admin.scss')
    ],
    "admin-lte": [
      path.resolve(__dirname, 'resources', 'webpack', 'js', 'admin-lte.js'),
      path.resolve(__dirname, 'resources', 'webpack', 'scss', 'admin-lte.scss')
    ],
    jquery: [
      path.resolve(__dirname, 'resources', 'webpack', 'js', 'jquery.js'),
    ],
    tagify: [
      path.resolve(__dirname, 'resources', 'webpack', 'js', 'tagify.js'),
      path.resolve(__dirname, 'resources', 'webpack', 'scss', 'tagify', 'tagify.scss')
    ],
    bootstrap: [
      path.resolve(__dirname, 'resources', 'webpack', 'js', 'bootstrap.js'),
      path.resolve(__dirname, 'resources', 'webpack', 'scss', 'bootstrap.scss'),
      path.resolve(__dirname, 'resources', 'webpack', 'scss', 'bootstrap-icons.scss'),
    ],
    maintenance: [
      path.resolve(__dirname, 'resources', 'webpack', 'scss', 'maintenance.scss'),
    ],
    fontAwesome: [
      path.resolve(__dirname, 'resources', 'webpack', 'scss', 'font-awesome.scss'),
    ],
    pygments: [
      path.resolve(__dirname, 'resources', 'webpack', 'scss', 'pygments.scss'),
    ],
  },
  output: {
    filename: isProd ? 'js/[name].[contenthash].js' : 'js/[name].js',
    assetModuleFilename: 'assets/[name][ext][query]',
    path: outputPath,
    publicPath: publicPath, // necessary for dynamic loading
    crossOriginLoading: "anonymous", // for SRI functionality
    clean: true,
    asyncChunks: true // @TODO: test if is working right on production
  },
  externalsType: 'commonjs',
  externals: {
    'ts-loader': 'ts-loader',
    'mermaid': 'mermaid'
    //jquery: "jQuery",
    //Tagify: 'Tagify',
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
        test: /\.css$/i,
        use: [
          MiniCssExtractPlugin.loader,
          {
            loader: 'css-loader',
            options: {
              importLoaders: 1,
              url: true, // optional: disable URL resolving if not needed
              modules: {
                mode: false,
              },
            },
          },
        ],
      },
      {
        test: /\.(s[ac]ss)$/i,
        use: [
          {
            loader: MiniCssExtractPlugin.loader,
            options: {
              publicPath: publicPath // optional
            }
          },
          {
            // Interprets `@import` and `url()` like `import/require()` and will resolve them
            loader: 'css-loader',
            options: {
              // Enable alias resolution in CSS:
              url: true,
              import: true,
              sourceMap: true,
              esModule: false,
            },
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
              additionalData: `$publicImgURL: "${process.env.STATIC_SUBDOMAIN}img";`,
              sassOptions: {
                silenceDeprecations: [
                  'mixed-decls',
                  'color-functions',
                  'global-builtin',
                  'import'
                ],
                outputStyle: "compressed",
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
          //filename: '[name][ext][query]',
          filename: (pathData) => {
            const pkg = getPackageFolderName(pathData.filename),
              fileName = path.basename(pathData.filename);
            //return `img/${pkg}/${fileName}`;
            return '[name][ext][query]';
          },
          publicPath: publicPath,
          //emit: false, // <- prevent emitting to dist/img/
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
      // For ttf/eot/svg fonts
      {
        test: /\.(woff2?|ttf|eot|svg|otf)(\?[\s\S]+)?(\?v=[0-9]\.[0-9]\.[0-9])?$/,
        type: 'asset/resource',
        generator: {
          filename: 'fonts/[name][ext][query]',
          //publicPath: '../wp/', // relative path from CSS to fonts
          // filename: (pathData) => {
          //   const pkg = getPackageFolderName(pathData.filename);
          //   const fileName = path.basename(pathData.filename);
          //   return `fonts/${pkg}/${fileName}`;
          // }
        }
      },
    ]
  },

  optimization: {
    runtimeChunk: {
      name: 'runtime',
    },
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
    new RemoveEmptyScriptsPlugin({ verbose: isProd !== true }),
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
    new SubresourceIntegrityPlugin({
      hashFuncNames: ['sha384'], // Recommended by browsers
      enabled: true

    }),
    new WebpackManifestPlugin({
      fileName: 'manifest.json',
      publicPath: 'wp',
      generate: (seed, files) => {
        const manifest = {};
        files.forEach(file => {
          if (!file.path.endsWith('.map')) {
            manifest[file.name] = {
              path: file.path,
              integrity: file.integrity || null
            };
          }
        });
        return manifest;
      }
    }),
    new CopyWebpackPlugin({
      patterns: [
        // {
        //   from: path.resolve(__dirname, 'resources', 'public/'),
        //   to: path.resolve(__dirname, 'resources', 'dist', )
        // },
        {
          from: path.resolve(__dirname, 'node_modules/bootstrap-icons/font/fonts'),
          to: path.resolve(__dirname, 'resources', 'dist', 'wp', 'fonts')
        }
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
      '@scss': path.resolve(__dirname, 'src/scss'),
      //'@img': path.resolve(__dirname, 'public/img/'),
      '@publicImgROOT': path.resolve(__dirname, 'resources', 'public', 'img'),
      '@publicImgURL': 'https:' + process.env.STATIC_SUBDOMAIN + 'img'
    },
    extensions: ['.tsx', '.ts', '.js', 'jsx', '.scss']
  },
  watch: true, // 🔁 Enable watching
  watchOptions: {
    ignored: /node_modules/,
    aggregateTimeout: 300,
    poll: 500 // or set to `false` to use native file system events
  },
  stats: {
    errorDetails: true,
    errorStack: true,
    errors: true,
    assets: true,
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
