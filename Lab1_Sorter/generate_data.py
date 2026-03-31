import random
NUM_BLOCK = 4
BLOCK_SIZE = 32
random.seed(0)

with open("input.txt","w") as fin, open("golden.txt","w") as fout:
    for _ in range(NUM_BLOCK):
        nums = [random.randint(-256,255) for _ in range(BLOCK_SIZE)]
        # input 32 numbers
        fin.write(" ".join(map(str,nums))+"\n")
        # golden answer (Top4 descending)
        top4 = sorted(nums, reverse=True)[:4]
        print(top4)
        fout.write(" ".join(map(str,top4))+"\n")