const path = require("path");

module.exports = {
  mode: "production",
  devtool: "source-map",
  entry: "./src/index.ts",
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        loader: "ts-loader",
        options: { projectReferences: true },
        exclude: /node_modules/,
      },
    ],
  },
  resolve: {
    extensions: [".js", ".tsx", ".ts"],
    alias: {
      "@quri/squiggle-lang": path.resolve(__dirname, '../squiggle-lang/src/js')
    },
  },
  output: {
    filename: "bundle.js",
    path: path.resolve(__dirname, "dist"),
    library: {
      name: "squiggle_components",
      type: "umd",
    },
  },
  devServer: {
    static: {
      directory: path.join(__dirname, "public"),
    },
    compress: true,
    port: 9000,
  },
};