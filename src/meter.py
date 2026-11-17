"""One fresh meter process per command; RUSAGE_CHILDREN has one child only."""
import json,resource,subprocess,sys,time
report=sys.argv[1]
start=time.perf_counter()
result=subprocess.run(sys.argv[2:])
wall=time.perf_counter()-start
rss=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
# Linux: KiB; macOS: bytes. Notebook target is Linux.
if sys.platform=='darwin':rss/=1024
with open(report,'w') as f:json.dump(dict(wall_seconds=wall,peak_rss_mib=rss/1024),f)
sys.exit(result.returncode)
