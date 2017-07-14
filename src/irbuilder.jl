# An instruction builder represents a point within a basic block and is the exclusive means
# of building instructions using the C interface.

export Builder,
       position!,
       debuglocation, debuglocation!

import Base: position, insert!

@reftypedef ref=LLVMBuilderRef immutable Builder end

Builder() = Builder(API.LLVMCreateBuilder())
Builder(ctx::Context) = Builder(API.LLVMCreateBuilderInContext(ref(ctx)))

dispose(builder::Builder) = API.LLVMDisposeBuilder(ref(builder))

function Builder(f::Core.Function, args...)
    builder = Builder(args...)
    try
        f(builder)
    finally
        dispose(builder)
    end
end

position(builder::Builder) = BasicBlock(API.LLVMGetInsertBlock(ref(builder)))
position!(builder::Builder, inst::Instruction) =
    API.LLVMPositionBuilderBefore(ref(builder), ref(inst))
position!(builder::Builder, bb::BasicBlock) =
    API.LLVMPositionBuilderAtEnd(ref(builder), blockref(bb))
position!(builder::Builder) = API.LLVMClearInsertionPosition(ref(builder))

insert!(builder::Builder, inst::Instruction) =
    API.LLVMInsertIntoBuilder(ref(builder), ref(inst))
insert!(builder::Builder, inst::Instruction, name::String) =
    API.LLVMInsertIntoBuilderWithName(ref(builder), ref(inst), name)

debuglocation(builder::Builder) =
    MetadataAsValue(API.LLVMGetCurrentDebugLocation(ref(builder)))
debuglocation!(builder::Builder) =
    API.LLVMSetCurrentDebugLocation(ref(builder), ref(Value, C_NULL))
debuglocation!(builder::Builder, loc::MetadataAsValue) =
    API.LLVMSetCurrentDebugLocation(ref(builder), ref(loc))
debuglocation!(builder::Builder, inst::Instruction) =
    API.LLVMSetInstDebugLocation(ref(builder), ref(inst))


## build methods

# NOTE: we can't use type information for differentiating eg. add! and fadd! based on args,
#       as ArgumentKind (LLVM's way of referring to contained function arguments) is untyped

export unreachable!, ret!, add!, fadd!, icmp!, br!, alloca!, call!, gep!, store!, bitcast!

unreachable!(builder::Builder) =
    Instruction(API.LLVMBuildUnreachable(ref(builder)))

ret!(builder::Builder) =
    Instruction(API.LLVMBuildRetVoid(ref(builder)))

ret!(builder::Builder, val::Value) =
    Instruction(API.LLVMBuildRet(ref(builder), ref(val)))

add!(builder::Builder, lhs::Value, rhs::Value, name::String="") =
    Instruction(API.LLVMBuildAdd(ref(builder), ref(lhs),
                                            ref(rhs), name))

fadd!(builder::Builder, lhs::Value, rhs::Value, name::String="") =
    Instruction(API.LLVMBuildFAdd(ref(builder), ref(lhs),
                                            ref(rhs), name))

icmp!(builder::Builder, op::API.LLVMIntPredicate, rhs::Value,
	lhs::Value, name::String="") = 
	Instruction(API.LLVMBuildICmp(ref(builder), op, ref(rhs), ref(lhs), name))

br!(builder::Builder, dest::BasicBlock) =
    Instruction(API.LLVMBuildBr(ref(builder), blockref(dest)))

br!(builder::Builder, ifval::Value, thenbb::BasicBlock, elsebb::BasicBlock) =
    Instruction(API.LLVMBuildCondBr(ref(builder),
                                               ref(ifval),
                                               blockref(thenbb),
                                               blockref(elsebb)))

alloca!(builder::Builder, typ::LLVMType, name::String="") =
    Instruction(API.LLVMBuildAlloca(ref(builder), ref(typ), name))

function call!(builder::Builder, fn::LLVM.Function, args::Vector=Value[], name::String="")
    @assert all(v->isa(v,Value), args)
    Instruction(API.LLVMBuildCall(ref(builder), ref(fn), ref.(args),
                                  Cuint(length(args)), name))
end

function gep!(builder::Builder, ptr::Value, indices::Vector, name::String="")
    @assert all(v->isa(v,Value), indices)
    Instruction(API.LLVMBuildGEP(ref(builder), ref(ptr), ref.(indices), Cuint(length(indices)), name))
end

function store!(builder::Builder, val::Value, ptr::Value)
    @assert isa(llvmtype(ptr), PointerType)
    Instruction(API.LLVMBuildStore(ref(builder), ref(val), ref(ptr)))
end

bitcast!(builder::Builder, val::Value, typ::LLVMType, name::String="") =
    Instruction(API.LLVMBuildBitCast(ref(builder), ref(val), ref(typ), name))