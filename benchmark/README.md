# Benchmark Guide 🧭📈

## Installation

To install the benchmark CLI, execute the following command:

```bash
julia -e 'using Pkg; Pkg.add("AirspeedVelocity"); Pkg.build("AirspeedVelocity")'
```

This installation will create three executables in the `~/.julia/bin` folder: `benchpkg`, `benchpkgplot`, and `benchpkgtable`. It is necessary to add them to your `$PATH` to use them from any terminal session.

### Add to PATH Temporarily

To temporarily add the path to your session:

```bash
export PATH="$PATH:~/.julia/bin"
```

### Add to PATH Permanently

To permanently add the executables to your path, append the following line to your `.zshrc` or `.bashrc` file:

```bash
echo 'export PATH="$PATH:~/.julia/bin"' >> ~/.zshrc  # For zsh users
echo 'export PATH="$PATH:~/.julia/bin"' >> ~/.bashrc  # For bash users
```

## Running Benchmarks

To run benchmarks, simply execute the following command in the shell:

```bash
benchpkg
```

and it will:

1. Figure out the package name (from Project.toml)
2. Figure out the default branch name to compare the dirty state of your repo against
3. Evaluate all the benchmarks in benchmarks/benchmark.jl (BenchmarkTools.jl format – i.e., const SUITE = BenchmarkGroup())
4. Print the result in a nicely formatted markdown table

You can use the `--filter` option to quickly check if the load time has worsened compared to the master branch:

```bash
benchpkg --filter=time_to_load
```

The `benchpkg` was updated in June 2024 to automate the benchmark without specifying the parameters. 
To specify additional condition in `benchpkg` and to work with `benchpkgplot` consult the help command (`--h`).

Here’s an improved and completed version of your README section, with the necessary definitions, examples, and explanations:

---

## Comparing Two or More Different Revisions (States)

To compare two or more different states of your codebase, you can use revisions. In this context, a **revision** refers to a specific state of the repository, which can be identified by a commit hash or a tag.

### (Reminder) What is a Revision?

A **revision** in Git is an identifier that refers to a specific state of the repository at a particular point in time. Revisions can be specified using:
- **Commit Hashes**: A unique SHA-1 identifier for each commit, e.g., `8b8a68f5b54f8fbb863f73c08f5c7fd0d3812ccd`.
- **Tags**: Human-readable names assigned to specific commits, often used to mark release points (e.g., `v1.0.0`).

### How to Add a Tag

You can create a tag in Git by using the following command:

```bash
git tag -a <tag-name> -m "Tag message"
```

For example, to tag the current commit with `v1.0.0`, you would run:

```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
```

To push the tag to the remote repository, use:

```bash
git push origin <tag-name>
```

For example:

```bash
git push origin v1.0.0
```

To see information about all tags, such as the commit they point to and the tag messages, use:

```bash
git show-ref --tags && git tag -n | while IFS= read -r line; do echo "$line"; done
```

### Example: Using Commit Hashes to Compare Revisions

Here is an example of how to use commit hashes to compare different revisions:

```bash
benchpkg --rev=8b8a68f5b54f8fbb863f73c08f5c7fd0d3812ccd,6fb48706f988613860c6c98beef32c32e900737b \
    --bench-on=8b8a68f5b54f8fbb863f73c08f5c7fd0d3812ccd --exeflags="--threads=8"
```

In this example, `benchpkg` compares the two specified revisions, with the first hash being the baseline for comparison.

### Example: Using Tags to Compare Revisions

Here’s how you can use tags instead of commit hashes:

1. **Create Tags**: 
   Suppose you want to tag the two commits:

   ```bash
   git tag -a v1.0.0 8b8a68f5b54f8fbb863f73c08f5c7fd0d3812ccd -m "Tagging v1.0.0"
   git tag -a v1.1.0 6fb48706f988613860c6c98beef32c32e900737b -m "Tagging v1.1.0"
   ```

2. **Use Tags in `benchpkg`**:
   Once the tags are set, you can use them in the comparison:

   ```bash
   benchpkg --rev=v1.0.0,v1.1.0 --bench-on=v1.0.0 --exeflags="--threads=8"
   ```

### How to Remove a Tag

If you need to remove a tag from your repository, you can do so with the following commands:

1. **Delete the tag locally**:

   ```bash
   git tag -d <tag-name>
   ```

   For example:

   ```bash
   git tag -d v1.0.0
   ```

2. **Delete the tag from the remote repository**:

   ```bash
   git push origin --delete <tag-name>
   ```

   For example:

   ```bash
   git push origin --delete v1.0.0
   ```

## Developer Notes

1. The `benchpkg` tool compares different revisions, allowing you to specify the commits or tags you wish to compare. It is crucial to ensure that both commits include all necessary dependencies; otherwise, the dependencies might not be resolved.

2. **AirSpeedVelocity**: Note that AirSpeedVelocity requires the benchmarking suite to be named `SUITE`. Any other names will not be recognized, which could lead to errors in your benchmarking process.
