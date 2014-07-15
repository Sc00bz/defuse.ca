# Blind Birthday Attack. Proof of concept.
# https://defuse.ca/blind-birthday-attack.htm

require 'securerandom'
require 'openssl'

# Use 32-bit HMAC so that it's actually possible to perform the attack in
# a reasonable amount of time. This value must be a multiple of 8.
HMAC_BITS = 32

# Compute HMAC-SHA256
def hmac(key, message)
  return OpenSSL::HMAC::digest('SHA256', key, message)[0, HMAC_BITS/8]
end

# Here's the oracle, which we are attackking.  t has a 256-bit random secret
# key. When we give it two inputs a and b, it HMACs them both, and tells us how
# much of the HMACs match.
KEY = SecureRandom.random_bytes(32)
def oracle(a, b)
  h1 = hmac(KEY, a)
  h2 = hmac(KEY, b)
  h1_binary = h1.bytes.map { |c| c.to_s(2).rjust(8,'0') }.join('').split('')
  h2_binary = h2.bytes.map { |c| c.to_s(2).rjust(8,'0') }.join('').split('')
  0.upto(HMAC_BITS - 1) do |i|
    if h1_binary[i] != h2_binary[i]
      return i
    end
  end
  return HMAC_BITS
end

# Here's an implementation of the attack.

# We organize messages into a tree to find collisions.
class TreeNode
  attr_accessor :message, :left, :right
end

# We need a good supply of unique messages.
def random
  return SecureRandom.random_bytes(32)
end

def attack
  # Start the tree with one random message.
  root = TreeNode.new
  root.message = random()

  # Keep track of how much resources we use for the attack.
  queries = 0
  tree_size = 0
  closest = 0

  # Each time this outer loop iterates, a new message is added to the tree.
  loop do
    
    # Generate a new random message to add to the tree.
    newnode = TreeNode.new
    newnode.message = random()
    
    # Start inserting at the root of the tree.
    current = root

    # Keep track of how deep we are into the tree.
    # This is the number of HMAC bits that are known to match between the
    # 'current' node's message and the newnode's message.
    matching = 0


    # Each time this inner loop iterates, we go one level deeper into the tree.
    loop do

      # Ask the oracle how many bits the two HMACs match.
      thismatch = oracle(current.message, newnode.message)
      queries += 1

      # If we have a better match than ever before, tell the user, so that they
      # don't get bored and quit the attack before it finishes.
      if thismatch > closest
        closest = thismatch
        puts "Closest collision so far: #{thismatch}"
        puts "Tree size: #{tree_size}"
      end

      # If we found a collision, tell the user and stop the attack.
      if thismatch == HMAC_BITS && current.message != newnode.message
        puts "Found a collision amongst #{tree_size} in #{queries} queries!"
        puts "Message 1: #{current.message.unpack("H*")[0]}"
        puts "Message 2: #{newnode.message.unpack("H*")[0]}"
        return
      end

      # If the (matching+1)st HMAC bit matches, we go right. Else, left.
      if thismatch > matching
        # If the right node is nil, this is where we add the new node.
        if current.right.nil?
          current.right = newnode
          tree_size += 1
          break
        end
        # Otherwise, just move on to the next level.
        current = current.right
      else
        # If the left node is nil, this is where we add the new node.
        if current.left.nil?
          current.left = newnode
          tree_size += 1
          break
        end
        # Otherwise, just move on to the next level.
        current = current.left
      end

      # We've moved down to the next level.
      matching += 1
    end

  end
end

attack()
