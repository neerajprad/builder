import re
import subprocess 
import sys

PY3 = sys.version_info >= (3, 0)

reinforce_cmd = 'python examples/reinforcement_learning/reinforce.py'
actor_critic_cmd = 'python examples/reinforcement_learning/actor_critic.py'


def run(command, timeout):
    """
    Returns (return-code, stdout, stderr)
    """
    p = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, err = p.communicate(timeout=timeout)
    rc = p.returncode
    if PY3:
        output = output.decode("ascii")
        err = err.decode("ascii")
    return (rc, output, err)


def check_cartpole_example(command, seconds=30, baseline_iter=1000):
    """
    Runs command. Checks that:
    1. the command exits within a timeout
    2. cartpole is solved
    3. the number of iters it takes to solve cartpole is less than baseline_iter
    """
    (rc, stdout, stderr) = run(command, timeout=seconds)
    print("stdout:\n", stdout)
    print("stderr:\n", stderr)
    if rc is not 0:
        sys.exit(rc)

    # Reinforce should have solved cartpole
    matches = re.search('Solved!', stdout)
    if matches is None:
        print("error: reinforce didn't solve cartpole")
        sys.exit(1)

    matches = re.findall('Episode (\d+)', stdout)
    if len(matches) is 0:
        print("error: unexpected output: ", stdout)
        sys.exit(1)

    losses = [int(m) for m in matches]

    if losses[-1] > baseline_iter:
        print("error: too many iterations taken: {}".format(losses[-1]))
        sys.exit(1)


if __name__ == '__main__':
    check_cartpole_example(actor_critic_cmd, seconds=5*60, baseline_iter=4000)
    check_cartpole_example(reinforce_cmd, seconds=60, baseline_iter=4000)

