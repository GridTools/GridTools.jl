
# Guide to Using JFrog with Sarus on Daint

## Steps to Follow

1. **Generate an API Key**
   - Go to [JFrog User Profile](https://jfrog.svc.cscs.ch/ui/user_profile) to generate your API key.

2. **Get the JFrog Link**
   - Navigate to the CI output of the `build_image` stage.
   - Scroll to the bottom and copy the JFrog link. It should look something like this:
     ```
     jfrog.svc.cscs.ch/docker-ci-ext/4852289723623970/pasc_kilos/daint-p100/gridtools_jl_image:13a8ca25
     ```

3. **Login on Daint**
   - Ensure you are logged into the Daint system.

4. **Execute the Following Commands**
   ```bash
   module load sarus
   sarus pull --login jfrog.svc.cscs.ch/docker-ci-ext/4852289723623970/pasc_kilos/daint-p100/gridtools_jl_image:13a8ca25
   sarus run -t jfrog.svc.cscs.ch/docker-ci-ext/4852289723623970/pasc_kilos/daint-p100/gridtools_jl_image:13a8ca25 bash -i -l
   . /opt/gridtools_jl_env/setup-env.sh
   cd /opt/GridTools
   julia --project=. -e 'using Pkg; Pkg.test()' # or whatever Julia command you want to run
   ```

## Notes
- Be aware that as soon as you exit the shell of the container, everything you have done in there is gone.
- The `sarus pull` command will ask for your username and password. Use your CSCS username and the API key as the password.