----------------------------------------------------------------
--- LAB --------------------------------------------------------
----------------------------------------------------------------
https://killercoda.com/chadmcrowell/course/cka/database-operator
----------------------------------------------------------------

# First, go to GitHub and fork the Postgres Operator examples repository.

# Once you have forked this repo, you can clone your forked repo with the following commands:L

# set your username
export GITHUB_USERNAME="<your-github-username>"
# clone the repo
git clone --depth 1 "https://github.com/${GITHUB_USERNAME}/postgres-operator-examples.git"

# change directory 
cd postgres-operator-examples
# You can install PGO, the Postgres Operator from Crunchy Data, using the following command.

kubectl apply -k kustomize/install/namespace
kubectl apply --server-side -k kustomize/install/default
# This will create a namespace called postgres-operator  and create all of the objects required to deploy PGO.

# To check on the status of your installation, you can run the following command.

k -n postgres-operator get po -w

k get crds | grep postgres
# If the PGO Pod is healthy, you should see output similar to this.

# NAME                                READY   STATUS    RESTARTS   AGE
# postgres-operator-9dd545d64-t4h8d   1/1     Running   0          3s

#Let's create a simple Postgres cluster. You can do this by executing the following command.

k apply -k kustomize/postgres
# This will create a Postgres cluster named hippo  in the postgres-operator  namespace.

# You can track the progress of your cluster using the following commands.

k -n postgres-operator get postgresclusters

k -n postgres-operator describe postgresclusters hippo
# As part of creating a Postgres cluster, the Postgres Operator creates a PostgreSQL user account. The credentials for this account are stored in a Secret that has the name hippo-pguser-rhino .

# List the secres in the postgres-operator namespace with the following command.

k -n postgres-operator get secrets

# __!!! Open a new tab !!!__ by clicking the plus sign at the top of the window, and create a port forward. You can run the following commands to create a port forward.
export PG_CLUSTER_PRIMARY_POD=$(kubectl get pod -n postgres-operator -o name -l postgres-operator.crunchydata.com/cluster=hippo,postgres-operator.crunchydata.com/role=master)
kubectl -n postgres-operator port-forward "${PG_CLUSTER_PRIMARY_POD}" 5432:5432
# Establish a connection to the PostgreSQL cluster. You can run the following commands to store the username, password, and database in an environment variable and connect.

export PG_CLUSTER_USER_SECRET_NAME=hippo-pguser-hippo
export PGPASSWORD=$(kubectl get secrets -n postgres-operator "${PG_CLUSTER_USER_SECRET_NAME}" -o go-template='{{.data.password | base64decode}}')
export PGUSER=$(kubectl get secrets -n postgres-operator "${PG_CLUSTER_USER_SECRET_NAME}" -o go-template='{{.data.user | base64decode}}')
export PGDATABASE=$(kubectl get secrets -n postgres-operator "${PG_CLUSTER_USER_SECRET_NAME}" -o go-template='{{.data.dbname | base64decode}}')
echo -e "\nPGPASSWORD=$PGPASSWORD\nPGUSER=$PGUSER\nPGDATABASE=$PGDATABASE\n"

psql -h localhost


# Create a Schema with the following command.
CREATE SCHEMA rhino AUTHORIZATION hippo;
\q
# In PostgreSQL, creating a schema establishes a namespace within a database that can organize and isolate database objects such as tables, views, indexes, functions, and other entities. It allows for better management of database objects, particularly in environments where multiple users or applications interact with the same database.
# Exit out of the postgres cli.

# Scaling a PostgreSQL cluster managed by the Crunchy Data Postgres Operator involves modifying the PostgresCluster Custom Resource Definition (CRD) to adjust the number of PostgreSQL instances (pods). The operator will handle the scaling process automatically once the changes are applied.
# Fetch the current PostgresCluster YAML configuration to understand its structure. Look for the instances section under the spec field.
k -n postgres-operator get postgresclusters hippo -o yaml

# Edit the hippo postgres cluster in order to change the replica count.
kubectl edit postgresclusters hippo -n postgres-operator
    # |--> To scale the cluster, increase the number of replicas in the PostgresCluster to 3.
    spec:
    instances:
    - name: instance1
        replicas: 3

# Once the PostgresCluster resource is updated, the operator will detect the change and manage the scaling process. The operator will create 2 new pods.
kubectl -n postgres-operator get pods

# You can connect to the PostgreSQL service to verify it is handling requests correctly. The operator manages replicas and ensures the primary and replicas are in sync.
# If necessary, check the logs of the operator for scaling-related messages.
kubectl logs -n postgres-operator -l postgres-operator.crunchydata.com/control-plane=postgres-operator


# -----------------------
# Simulate a DB Failure
# -----------------------
# Simulating a pod failure in a Crunchy Data Postgres Operator-managed PostgreSQL cluster is a straightforward way to test the operator’s recovery mechanisms.

# List the pods in your PostgreSQL cluster namespace.
k -n postgres-operator get pods
# You can tell which pod is the leader with the following command.

k -n postgres-operator get pods --show-labels | grep role
# Choose a pod to delete (e.g., hippo-instance1-0 for the primary or a replica)

k -n postgres-operator delete po hippo-instance1-0 
# This will simulate a failure by removing the pod.

# The Crunchy Postgres Operator will automatically detect the failure and attempt to recover the pod.

k -n postgres-operator get pods  -w
# Check the PostgresCluster resource for events related to the recovery.

k -n postgres-operator describe postgresclusters hippo
# Look for events such as:

# The operator creating a new pod.
# Replica promotion (if the primary is deleted).
# Synchronization completion.
# Check the operator logs for detailed information about how it handles the failure.

k -n postgres-operator logs -l postgres-operator.crunchydata.com/control-plane=postgres-operator
# Look for messages about:
    # Pod recreation
    # Replica promotion (if necessary)
    # Readiness checks
    # Connect to the PostgreSQL database and run some basic queries to ensure it is functioning properly.

psql -h localhost

SELECT pg_is_in_recovery();
t : Indicates the node is a replica.
f : Indicates the node is the primary.
Since we deleted a replica, confirm replication is still functioning.

kubectl exec -it -n postgres-operator <replica-pod-name> -- psql -U postgres -d postgres
SELECT pg_last_wal_replay_lsn();
# This shows the replication status from the primary’s perspective.