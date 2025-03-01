.ONESHELL: # Source: https://stackoverflow.com/a/30590240
.SILENT: # https://stackoverflow.com/a/11015111


include .env
export $(shell sed 's/=.*//' .env)  # TODO: this fails if the vars are quoted

# TODO: shorthand command for executing in the ssh
# TODO: automate the initial clone of the repo
# TODO: `apptainer build  --disable-cache run_cluster.sif run_cluster.def` when necesary

run-cluster:
	sshpass -p '${SSH_PASSWORD_SHIBBOLETH}' ssh -o ProxyCommand="sshpass -p '${SSH_PASSWORD_CLUSTER}' ssh -W %h:%p ${SSH_USER_SHIBBOLETH}@users.itk.ppke.hu" ${SSH_USER_CLUSTER}@cl.itk.ppke.hu " \
		cd tutorial-ppke-cluster; \
		nohup \
		srun -pgpu --gres=gpu:v100:1 apptainer run --nv run_cluster.sif /usr/bin/tini -s -- jupyter notebook --port=8888 --no-browser --ip=0.0.0.0 --allow-root --NotebookApp.token=cfbc4b9c-7056-4a8c-8c34-3e521dd01cdb \
		> output.log 2>&1 & \
	"
	sleep 3

	JOB_ID=$$( \
		sshpass -p '${SSH_PASSWORD_SHIBBOLETH}' ssh -o ProxyCommand="sshpass -p '${SSH_PASSWORD_CLUSTER}' ssh -W %h:%p ${SSH_USER_SHIBBOLETH}@users.itk.ppke.hu" ${SSH_USER_CLUSTER}@cl.itk.ppke.hu "\
			sacct -u \$$USER --format=JobID,State,Start -n | sort -k3 -r | head -n 1 | awk '{print \$$1}' | sed 's/\..*\$$//' \
		"\
	)
	echo "Latest Job ID: $$JOB_ID"

	
	export NODE=$$( \
		sshpass -p '${SSH_PASSWORD_SHIBBOLETH}' ssh -o ProxyCommand="sshpass -p '${SSH_PASSWORD_CLUSTER}' ssh -W %h:%p ${SSH_USER_SHIBBOLETH}@users.itk.ppke.hu" ${SSH_USER_CLUSTER}@cl.itk.ppke.hu "\
			scontrol show job $$JOB_ID | grep -oP '(?<=NodeList=)\S+' | grep -v '(null)'\
		"\
	)
	echo "Node: $$NODE"

	echo "\n-------------------------------------------------------------------------\n"
	echo "Go to http://localhost:8888/tree?token=cfbc4b9c-7056-4a8c-8c34-3e521dd01cdb"
	echo "\n-------------------------------------------------------------------------\n"

	sshpass -p '${SSH_PASSWORD_SHIBBOLETH}' ssh -o ProxyCommand="sshpass -p '${SSH_PASSWORD_CLUSTER}' ssh -W %h:%p ${SSH_USER_SHIBBOLETH}@users.itk.ppke.hu" ${SSH_USER_CLUSTER}@cl.itk.ppke.hu -NTL 8888:$$NODE:8888


stop-cluster:
	# Stop all jobs from your user
	# Control-C stops the tunnel, but the slurm job is still running
	sshpass -p '${SSH_PASSWORD_SHIBBOLETH}' ssh -o ProxyCommand="sshpass -p '${SSH_PASSWORD_CLUSTER}' ssh -W %h:%p ${SSH_USER_SHIBBOLETH}@users.itk.ppke.hu" ${SSH_USER_CLUSTER}@cl.itk.ppke.hu " \
		scancel -u $$USER \
	"
